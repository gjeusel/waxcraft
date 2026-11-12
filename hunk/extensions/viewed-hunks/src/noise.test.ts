import assert from "node:assert/strict";
import { test } from "node:test";
import { askQuestions } from "./decisions.ts";
import { parseHunks } from "./hunks.ts";
import {
  DEFAULT_NOISE_PATHS,
  reachOf,
  isNoisePath,
  parseNoiseSettings,
  planNoiseRun,
  toVerdict,
  type ReviewFile,
} from "./noise.ts";

const SETTINGS = parseNoiseSettings({});

/** A file of `hunkCount` one-line hunks, each `lineLength` characters wide. */
function reviewFile(path: string, hunkCount = 1, lineLength = 10): ReviewFile {
  const hunks = Array.from({ length: hunkCount }, (_, index) => {
    const line = `${index}`.padEnd(lineLength, "x");

    return `@@ -${index * 10 + 1},1 +${index * 10 + 1},1 @@\n-old ${line}\n+new ${line}`;
  });

  return { path, hunks: parseHunks({ path, patch: hunks.join("\n") }) };
}

test("parseNoiseSettings keeps defaults for missing or unusable values", () => {
  assert.deepEqual(parseNoiseSettings({ noise_threshold: "high", noise_paths: "x", other: 1 }), {
    threshold: 0.9,
    paths: DEFAULT_NOISE_PATHS,
    maxFileChars: 64_000,
  });

  const settings = parseNoiseSettings({
    noise_threshold: 0.2,
    noise_paths: ["**/*.snap", 3],
    noise_max_file_chars: 500,
  });
  assert.equal(settings.threshold, 0.5);
  assert.deepEqual(settings.paths, [...DEFAULT_NOISE_PATHS, "**/*.snap"]);
  assert.equal(settings.maxFileChars, 500);
  assert.equal(parseNoiseSettings({ noise_threshold: 7 }).threshold, 1);
});

test("isNoisePath matches a bare pattern on the file name and a path pattern on the path", () => {
  const patterns = ["uv.lock", "*.min.js", "generated/**", "**/__snapshots__/*.ambr"];
  const isNoise = (path: string) => isNoisePath(path, patterns);

  assert.ok(isNoise("uv.lock"));
  assert.ok(isNoise("services/api/uv.lock"));
  assert.ok(isNoise("static/app.min.js"));
  assert.ok(isNoise("generated/client/api.ts"));
  assert.ok(isNoise("tests/__snapshots__/test_a.ambr"));
  assert.ok(!isNoise("src/uv.lock.py"));
  assert.ok(!isNoise("src/generated/api.ts"));
  assert.ok(!isNoise("tests/test_a.py"));
});

test("planNoiseRun sorts hunks into path noise, too large, and questions", () => {
  const lock = reviewFile("uv.lock", 2);
  const huge = reviewFile("big.json", 1, 400);
  const source = reviewFile("src/a.py", 2);
  const plan = planNoiseRun([lock, huge, source], () => false, { ...SETTINGS, maxFileChars: 300 });

  assert.deepEqual(plan.pathNoiseKeys, lock.hunks.map((hunk) => hunk.key));
  assert.deepEqual(plan.oversizedKeys, huge.hunks.map((hunk) => hunk.key));
  assert.equal(plan.requests.length, 1);

  const [request] = plan.requests;
  assert.deepEqual(
    request?.questions.map(({ name, key }) => [name, key]),
    source.hunks.flatMap((hunk, index) => [
      [`h${index}.noise`, hunk.key],
      [`h${index}.imports`, hunk.key],
      [`h${index}.structure`, hunk.key],
      [`h${index}.interface`, hunk.key],
    ]),
  );
  assert.match(request?.input ?? "", /## File: src\/a\.py\n\[hunk h0\]\n@@ -1,1 \+1,1 @@/);
  assert.doesNotMatch(request?.input ?? "", /uv\.lock|big\.json/);
});

test("planNoiseRun sends a judged hunk as context without asking about it", () => {
  const file = reviewFile("src/a.py", 3);
  const judgedKey = file.hunks[1]?.key;
  const plan = planNoiseRun([file], (key) => key === judgedKey, SETTINGS);

  assert.deepEqual(
    plan.requests[0]?.questions.filter((q) => q.kind === "noise").map((q) => q.name),
    ["h0.noise", "h2.noise"],
  );
  assert.match(plan.requests[0]?.input ?? "", /\[hunk h1\]/);

  const lock = reviewFile("uv.lock");
  const everythingJudged = planNoiseRun([file, lock], () => true, SETTINGS);
  assert.deepEqual(everythingJudged, { pathNoiseKeys: [], requests: [], oversizedKeys: [] });
});

test("planNoiseRun splits a review that exceeds one request, file by file", () => {
  // Four questions per hunk, 400 questions per request: 100 hunks fit.
  const files = [reviewFile("a.py", 70), reviewFile("b.py", 70), reviewFile("c.py", 30)];
  const tooManyHunks = reviewFile("d.py", 110);
  const settings = { ...SETTINGS, maxFileChars: 1_000_000 };
  const plan = planNoiseRun([...files, tooManyHunks], () => false, settings);

  assert.deepEqual(
    plan.requests.map((request) => request.questions.length),
    [280, 400],
  );
  assert.doesNotMatch(plan.requests[0]?.input ?? "", /b\.py/);
  assert.equal(plan.requests[1]?.questions[0]?.name, "h0.noise");
  assert.equal(plan.oversizedKeys.length, 110);
});

test("toVerdict lets an imports-only hunk be noise whatever the noise answer", () => {
  assert.deepEqual(toVerdict({ noise: 0.02, imports: 0.97, structure: 0.1, interface: 0.2 }), {
    noise: 0.97,
    structure: 0.1,
    interface: 0.2,
  });
  assert.deepEqual(toVerdict({ noise: 0.8 }), {
    noise: 0.8,
    structure: undefined,
    interface: undefined,
  });
  assert.equal(toVerdict({ imports: 1, structure: 0 }), null);
});

test("reachOf names the furthest level the model leaned towards", () => {
  const levelOf = (structure?: number, interfaceProbability?: number) =>
    reachOf({ noise: 0, structure, interface: interfaceProbability });

  assert.equal(levelOf(0.1, 0.49), "detail");
  assert.equal(levelOf(0.1, 0.5), "interface");
  assert.equal(levelOf(0.5, 0.1), "structure");
  assert.equal(levelOf(0.9, 0.9), "structure");
  assert.equal(levelOf(undefined, 0.7), "interface");
  assert.equal(levelOf(undefined, undefined), null);
});

test("askQuestions gathers the answers of each hunk and leaves a refusal out", async () => {
  const file = reviewFile("src/a.py", 2);
  const [request] = planNoiseRun([file], () => false, SETTINGS).requests;
  assert.ok(request);

  let sent: { url: string; headers: Record<string, string>; body: any } | undefined;
  const fakeFetch = (async (url: string, init: RequestInit) => {
    sent = {
      url,
      headers: init.headers as Record<string, string>,
      body: JSON.parse(String(init.body)),
    };

    return Response.json({
      answers: [
        { type: "predicate", name: "h1.structure", probability: 0.6 },
        { type: "predicate", name: "h0.noise", probability: 0.98 },
        { type: "refusal", name: "h0.imports" },
        { type: "predicate", name: "h1.noise", probability: 0.03 },
        { type: "predicate", name: "h1.imports", probability: 0.01 },
        { type: "predicate", name: "unknown", probability: 1 },
      ],
    });
  }) as typeof fetch;

  const signal = new AbortController().signal;
  const answers = await askQuestions(request, { apiKey: "sk-test", signal, fetch: fakeFetch });

  const [first, second] = file.hunks;
  assert.deepEqual(
    [...answers],
    [
      [second?.key, { structure: 0.6, noise: 0.03, imports: 0.01 }],
      [first?.key, { noise: 0.98 }],
    ],
  );
  assert.equal(sent?.url, "https://api.openai.com/v1/decisions");
  assert.equal(sent?.headers.Authorization, "Bearer sk-test");
  assert.equal(sent?.body.input, request.input);
  assert.deepEqual(sent?.body.questions[0], {
    type: "predicate",
    name: "h0.noise",
    instructions: "Is hunk h0 of src/a.py noise?",
  });
  assert.deepEqual(
    sent?.body.questions.map((question: { type: string }) => question.type),
    Array.from({ length: 8 }, () => "predicate"),
  );
});

test("askQuestions reports the API's own error message", async () => {
  const [request] = planNoiseRun([reviewFile("a.py")], () => false, SETTINGS).requests;
  assert.ok(request);

  const signal = new AbortController().signal;
  const failing = (async () =>
    Response.json({ error: { message: "Incorrect API key" } }, { status: 401 })) as typeof fetch;
  const garbled = (async () => new Response("<html>", { status: 502 })) as typeof fetch;

  await assert.rejects(
    askQuestions(request, { apiKey: "x", signal, fetch: failing }),
    /OpenAI answered 401: Incorrect API key/,
  );
  await assert.rejects(
    askQuestions(request, { apiKey: "x", signal, fetch: garbled }),
    /OpenAI answered 502: unexpected response/,
  );
});
