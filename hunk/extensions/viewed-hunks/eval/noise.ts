// Check the noise question against labelled hunks, with the real Decisions API:
//
//   OPENAI_API_KEY=... npm run eval:noise
//
// Run it before changing NOISE_CRITERIA or the default threshold. A hunk wrongly hidden is the
// costly mistake; a missed noise hunk only stays on screen.
import { askNoise } from "../src/decisions.ts";
import { parseHunks } from "../src/hunks.ts";
import { parseNoiseSettings, planNoiseRun } from "../src/noise.ts";
import { NOISE_CASES } from "./noise-cases.ts";

const THRESHOLDS = [0.5, 0.7, 0.8, 0.9, 0.95, 0.99];

const apiKey = process.env.OPENAI_API_KEY;
if (!apiKey) {
  console.error("OPENAI_API_KEY is not set.");
  process.exit(1);
}

const settings = parseNoiseSettings({});
const results: { isNoise: boolean; probability: number }[] = [];

for (const noiseCase of NOISE_CASES) {
  const files = noiseCase.files.map((file) => ({ path: file.path, hunks: parseHunks(file) }));
  const labels = new Map<string, { path: string; isNoise: boolean | null; what: string }>();
  for (const [fileIndex, file] of files.entries()) {
    const expected = noiseCase.files[fileIndex]?.hunks ?? [];
    if (expected.length !== file.hunks.length) {
      const counts = `${expected.length} labels for ${file.hunks.length} hunks`;
      throw new Error(`${noiseCase.name}: ${file.path} has ${counts}`);
    }

    for (const [hunkIndex, hunk] of file.hunks.entries()) {
      const [isNoise, what] = expected[hunkIndex] ?? [null, ""];
      labels.set(hunk.key, { path: file.path, isNoise, what });
    }
  }

  const plan = planNoiseRun(files, () => false, settings);
  const probabilities = new Map<string, number>();
  for (const request of plan.requests) {
    const answers = await askNoise(request, { apiKey, signal: new AbortController().signal });
    answers.forEach((probability, key) => probabilities.set(key, probability));
  }

  console.log(`\n${noiseCase.name}`);
  for (const [key, label] of labels) {
    const probability = probabilities.get(key);
    if (probability === undefined) {
      console.log(`  ?        no answer  ${label.path}: ${label.what}`);
      continue;
    }

    const expected = label.isNoise === null ? "  -  " : label.isNoise ? "noise" : "keep ";
    const isHidden = probability >= settings.threshold;
    const isWrong = label.isNoise !== null && label.isNoise !== isHidden;
    const mark = !isWrong ? " " : isHidden ? "✗" : "~";
    console.log(`  ${mark} ${probability.toFixed(2)}  ${expected}  ${label.path}: ${label.what}`);

    if (label.isNoise !== null) results.push({ isNoise: label.isNoise, probability });
  }
}

const noiseCount = results.filter((result) => result.isNoise).length;
const keepCount = results.length - noiseCount;
console.log(`\n${results.length} labelled hunks: ${noiseCount} noise, ${keepCount} to keep`);
console.log("✗ wrongly hidden   ~ noise left on screen\n");
console.log("threshold  wrongly hidden  noise left on screen");
for (const threshold of THRESHOLDS) {
  const wronglyHidden = results.filter((r) => !r.isNoise && r.probability >= threshold).length;
  const missed = results.filter((r) => r.isNoise && r.probability < threshold).length;
  const isDefault = threshold === settings.threshold ? "  (default)" : "";
  const counts = `${String(wronglyHidden).padStart(8)}  ${String(missed).padStart(18)}`;
  console.log(`  ${threshold.toFixed(2)}     ${counts}${isDefault}`);
}
