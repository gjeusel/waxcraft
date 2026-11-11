import assert from "node:assert/strict";
import { test } from "node:test";
import { askNoise } from "./decisions.ts";
import { parseHunks } from "./hunks.ts";
import {
  DEFAULT_NOISE_PATHS,
  isNoisePath,
  parseNoiseSettings,
  planNoiseRun,
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
    maxFileChars: 16_000,
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
    source.hunks.map((hunk, index) => [`h${index}`, hunk.key]),
  );
  assert.match(request?.input ?? "", /## File: src\/a\.py\n\[hunk h0\]\n@@ -1,1 \+1,1 @@/);
  assert.doesNotMatch(request?.input ?? "", /uv\.lock|big\.json/);
});

test("planNoiseRun sends a judged hunk as context without asking about it", () => {
  const file = reviewFile("src/a.py", 3);
  const judgedKey = file.hunks[1]?.key;
  const plan = planNoiseRun([file], (key) => key === judgedKey, SETTINGS);

  assert.deepEqual(
    plan.requests[0]?.questions.map((question) => question.name),
    ["h0", "h2"],
  );
  assert.match(plan.requests[0]?.input ?? "", /\[hunk h1\]/);

  const lock = reviewFile("uv.lock");
  const everythingJudged = planNoiseRun([file, lock], () => true, SETTINGS);
  assert.deepEqual(everythingJudged, { pathNoiseKeys: [], requests: [], oversizedKeys: [] });
});

test("planNoiseRun splits a review that exceeds one request, file by file", () => {
  const files = [reviewFile("a.py", 250), reviewFile("b.py", 250), reviewFile("c.py", 100)];
  const plan = planNoiseRun(files, () => false, { ...SETTINGS, maxFileChars: 1_000_000 });

  assert.deepEqual(
    plan.requests.map((request) => request.questions.length),
    [250, 350],
  );
  assert.doesNotMatch(plan.requests[0]?.input ?? "", /b\.py/);
  assert.equal(plan.requests[1]?.questions[0]?.name, "h0");
});

test("askNoise maps each answer back to its hunk and leaves a refusal out", async () => {
  const file = reviewFile("src/a.py", 3);
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
        { type: "predicate", name: "h2", probability: 0.03 },
        { type: "refusal", name: "h1" },
        { type: "predicate", name: "h0", probability: 0.98 },
        { type: "predicate", name: "unknown", probability: 1 },
      ],
    });
  }) as typeof fetch;

  const signal = new AbortController().signal;
  const answers = await askNoise(request, { apiKey: "sk-test", signal, fetch: fakeFetch });

  const [first, , third] = file.hunks;
  assert.deepEqual([...answers], [[third?.key, 0.03], [first?.key, 0.98]]);
  assert.equal(sent?.url, "https://api.openai.com/v1/decisions");
  assert.equal(sent?.headers.Authorization, "Bearer sk-test");
  assert.equal(sent?.body.input, request.input);
  assert.deepEqual(sent?.body.questions[0], {
    type: "predicate",
    name: "h0",
    instructions: "Is hunk h0 of src/a.py noise?",
  });
});

test("askNoise reports the API's own error message", async () => {
  const [request] = planNoiseRun([reviewFile("a.py")], () => false, SETTINGS).requests;
  assert.ok(request);

  const signal = new AbortController().signal;
  const failing = (async () =>
    Response.json({ error: { message: "Incorrect API key" } }, { status: 401 })) as typeof fetch;
  const garbled = (async () => new Response("<html>", { status: 502 })) as typeof fetch;

  await assert.rejects(
    askNoise(request, { apiKey: "x", signal, fetch: failing }),
    /OpenAI answered 401: Incorrect API key/,
  );
  await assert.rejects(
    askNoise(request, { apiKey: "x", signal, fetch: garbled }),
    /OpenAI answered 502: unexpected response/,
  );
});
