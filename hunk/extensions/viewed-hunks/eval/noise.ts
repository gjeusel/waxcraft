// Check the noise and reach questions against labelled hunks, with the real Decisions API:
//
//   OPENAI_API_KEY=... npm run eval:noise
//   OPENAI_API_KEY=... npm run eval:noise -- --diff changes.diff   (verdicts on a real diff)
//
// Run it before changing the wording in src/noise.ts or the default threshold. A hunk wrongly
// hidden is the costly mistake; a hunk left on screen only costs a glance.
import { readFileSync } from "node:fs";
import { askQuestions } from "../src/decisions.ts";
import { parseHunks } from "../src/hunks.ts";
import { parseNoiseSettings, planNoiseRun, reachOf, toVerdict } from "../src/noise.ts";
import type { Reach, Verdict } from "../src/noise.ts";
import { NOISE_CASES, type NoiseCase } from "./noise-cases.ts";

const THRESHOLDS = [0.5, 0.7, 0.8, 0.9, 0.95, 0.99];

const apiKey = process.env.OPENAI_API_KEY ?? "";
if (!apiKey) {
  console.error("OPENAI_API_KEY is not set.");
  process.exit(1);
}

const settings = parseNoiseSettings({});

/** One unlabelled case per `git diff` output: every hunk of every file. */
function caseOfDiff(path: string): NoiseCase {
  const sections = readFileSync(path, "utf8").split(/^diff --git /m).slice(1);
  const files = sections.map((section) => {
    const filePath = /^\+\+\+ b\/(.+)$/m.exec(section)?.[1] ?? /^--- a\/(.+)$/m.exec(section)?.[1];
    const patch = section.slice(Math.max(0, section.search(/^@@ /m)));
    const hunkCount = parseHunks({ path: filePath ?? "", patch }).length;

    return {
      path: filePath ?? "(unknown)",
      patch,
      hunks: Array.from({ length: hunkCount }, (): [null, string] => [null, ""]),
    };
  });

  return { name: path, files };
}

async function judge(noiseCase: NoiseCase) {
  const files = noiseCase.files.map((file) => ({ path: file.path, hunks: parseHunks(file) }));
  const plan = planNoiseRun(files, () => false, settings);
  const verdicts = new Map<string, Verdict>();
  for (const request of plan.requests) {
    const answers = await askQuestions(request, { apiKey, signal: new AbortController().signal });
    for (const [key, hunkAnswers] of answers) {
      const verdict = toVerdict(hunkAnswers);
      if (verdict) verdicts.set(key, verdict);
    }
  }
  for (const key of plan.pathNoiseKeys) verdicts.set(key, { noise: 1 });

  return { files, verdicts };
}

const diffPath = process.argv.includes("--diff")
  ? process.argv[process.argv.indexOf("--diff") + 1]
  : undefined;
const isDiffRun = diffPath !== undefined;
const cases = diffPath !== undefined ? [caseOfDiff(diffPath)] : NOISE_CASES;

const results: { isNoise: boolean; probability: number }[] = [];
const reachResults: { expected: Reach; isShown: boolean; level: Reach | null }[] = [];
const tally = { noise: 0, detail: 0, interface: 0, structure: 0, unjudged: 0 };

for (const noiseCase of cases) {
  const { files, verdicts } = await judge(noiseCase);

  console.log(`\n${noiseCase.name}`);
  for (const [fileIndex, file] of files.entries()) {
    const labels = noiseCase.files[fileIndex]?.hunks ?? [];
    if (labels.length !== file.hunks.length) {
      const counts = `${labels.length} labels for ${file.hunks.length} hunks`;
      throw new Error(`${noiseCase.name}: ${file.path} has ${counts}`);
    }

    for (const [hunkIndex, hunk] of file.hunks.entries()) {
      const [isNoise, what, expectedReach] = labels[hunkIndex] ?? [null, ""];
      const verdict = verdicts.get(hunk.key);
      const where = `${file.path}:${hunk.line}${what ? `: ${what}` : ""}`;
      if (!verdict) {
        tally.unjudged += 1;
        console.log(`    ?     no answer        ${where}`);
        continue;
      }

      const isHidden = verdict.noise >= settings.threshold;
      const level = reachOf(verdict);
      // The architecture view shows what is neither noise nor a detail.
      const isShown = !isHidden && level !== null && level !== "detail";
      tally[isHidden ? "noise" : (level ?? "unjudged")] += 1;

      const isNoiseWrong = isNoise !== null && isNoise !== isHidden;
      const isReachWrong = expectedReach !== undefined && isShown !== (expectedReach !== "detail");
      const strictMark = !isNoiseWrong ? " " : isHidden ? "✗" : "~";
      const reachMark = !isReachWrong ? " " : isShown ? "+" : "✗";
      const expected = [
        isNoise === null ? "" : isNoise ? "noise" : "keep",
        expectedReach ?? "",
      ].join(" ");
      const probabilities = [verdict.noise, verdict.structure ?? 0, verdict.interface ?? 0];
      const scores = probabilities.map((probability) => probability.toFixed(2)).join(" ");
      const got = (isHidden ? "noise" : (level ?? "?")).padEnd(9);
      console.log(`  ${strictMark}${reachMark} ${scores} ${got} | ${expected.padEnd(15)} ${where}`);

      if (isNoise !== null) results.push({ isNoise, probability: verdict.noise });
      if (expectedReach !== undefined) {
        reachResults.push({ expected: expectedReach, isShown, level });
      }
    }
  }
}

const total = Object.values(tally).reduce((sum, count) => sum + count, 0);
console.log(`\n${total} hunks: ${JSON.stringify(tally)}`);
console.log(`architecture view shows ${tally.interface + tally.structure} of ${total}`);

if (!isDiffRun) {
  const noiseCount = results.filter((result) => result.isNoise).length;
  const keepCount = results.length - noiseCount;
  const labelled = `${results.length} labelled hunks`;
  console.log(`\nstrict: ${labelled}, ${noiseCount} noise, ${keepCount} to keep`);
  console.log("first column: ✗ wrongly hidden   ~ noise left on screen\n");
  console.log("threshold  wrongly hidden  noise left on screen");
  for (const threshold of THRESHOLDS) {
    const wronglyHidden = results.filter((r) => !r.isNoise && r.probability >= threshold).length;
    const missed = results.filter((r) => r.isNoise && r.probability < threshold).length;
    const isDefault = threshold === settings.threshold ? "  (default)" : "";
    const counts = `${String(wronglyHidden).padStart(8)}  ${String(missed).padStart(18)}`;
    console.log(`  ${threshold.toFixed(2)}     ${counts}${isDefault}`);
  }

  const structural = reachResults.filter((result) => result.expected !== "detail");
  const details = reachResults.filter((result) => result.expected === "detail");
  const wrongLevel = structural.filter((r) => r.isShown && r.level !== r.expected).length;
  console.log(`\narchitecture: ${reachResults.length} labelled hunks`);
  console.log("second column: ✗ wrongly hidden   + detail left on screen");
  const hiddenCount = structural.filter((r) => !r.isShown).length;
  const shownCount = details.filter((r) => r.isShown).length;
  console.log(`  interface or structure hidden: ${hiddenCount} of ${structural.length}`);
  console.log(`  details left on screen:        ${shownCount} of ${details.length}`);
  console.log(`  shown at the other level:      ${wrongLevel} of ${structural.length}`);
}
