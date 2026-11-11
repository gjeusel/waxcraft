// What a noise hunk is, and how a review is turned into Decisions API requests asking for it.
//
// A noise hunk is one a reviewer can verify at a glance. Lockfile-like paths are noise by rule;
// every other hunk is judged by the model, which sees the whole diff so that it can tell the
// origin of a change from the hunks that only follow it. Moved code is never noise: the model
// cannot tell an unchanged move from an edited one.
import { basename, matchesGlob } from "node:path";
import type { ParsedHunk } from "./hunks.ts";

/** Files that are noise whatever they contain; a pattern without `/` matches the file name. */
export const DEFAULT_NOISE_PATHS = [
  "package-lock.json",
  "npm-shrinkwrap.json",
  "yarn.lock",
  "pnpm-lock.yaml",
  "bun.lock",
  "bun.lockb",
  "uv.lock",
  "poetry.lock",
  "Pipfile.lock",
  "Cargo.lock",
  "flake.lock",
  "go.sum",
  "Gemfile.lock",
  "composer.lock",
];

// About 60k tokens: several requests of this size still answer within a few seconds.
const MAX_REQUEST_CHARS = 240_000;
// The Decisions API accepts at most 400 questions per request.
const MAX_REQUEST_QUESTIONS = 400;

/** Re-run `npm run eval:noise` before changing this wording. */
export const NOISE_CRITERIA = `You help a code reviewer skip noise. The diff above is split into files and hunks. Each hunk is introduced by a line such as \`[hunk h3]\`.

A hunk is NOISE when a reviewer can verify it at a glance, without reasoning about new behavior. That is a hunk which only:
- follows a change made in another hunk of this diff: a call site, import, test, comment or doc updated for a rename or a changed signature
- reformats, rewraps or reorders code (imports, members, keys, definitions) without changing its content
- deletes something another hunk made useless, such as an import that is no longer used
- fixes a typo, or updates a comment or doc to match a name or value changed elsewhere
- adds or adjusts type annotations without changing what callers may pass or receive
- rewords a log, error or user-facing message without changing when it is emitted
- changes a generated file in a way that carries no meaning: timestamps, hashes, ids, ordering

A hunk is NOT noise when it:
- adds, removes or changes logic, behavior, a default, a constant or a setting, however small
- is the origin other hunks follow: the renamed definition, the changed signature
- removes code on its own: a function, a branch, a check, a feature
- adds a new test or new assertions
- adds or rewrites a comment, a docstring or documentation
- touches a manifest or a configuration file (dependencies, build, CI, lint, settings), whatever the change
- moves a block of code to another place, edited or not: neither the place it leaves nor the place it arrives is noise
- changes a snapshot or a generated API schema in a way that reflects a real change of output or contract

Read the whole diff before judging a hunk: the change it follows can be in any file, before or after it.

When in doubt, the hunk is not noise.`;

export interface NoiseSettings {
  /** A hunk is noise from this probability up. */
  threshold: number;
  /** Globs of files that are noise without asking the model. */
  paths: string[];
  /** A file with more changed text than this is neither sent nor judged. */
  maxFileChars: number;
}

export interface ReviewFile {
  path: string;
  hunks: readonly ParsedHunk[];
}

export interface NoiseRequest {
  /** The diff followed by the criteria, shared by every question. */
  input: string;
  questions: { name: string; instructions: string; key: string }[];
}

export interface NoisePlan {
  /** Keys of unjudged hunks in files that are noise by path. */
  pathNoiseKeys: string[];
  requests: NoiseRequest[];
  /** Keys of unjudged hunks left out because their file is too large. */
  oversizedKeys: string[];
}

/** Read `[extension.viewed-hunks]`. A reviewed repository can set it: keep values in bounds. */
export function parseNoiseSettings(config: Record<string, unknown>): NoiseSettings {
  const { noise_threshold: threshold, noise_paths: paths, noise_max_file_chars: maxChars } = config;
  const extraPaths = Array.isArray(paths) ? paths.filter((path) => typeof path === "string") : [];

  return {
    threshold: typeof threshold === "number" ? Math.min(Math.max(threshold, 0.5), 1) : 0.9,
    paths: [...DEFAULT_NOISE_PATHS, ...extraPaths],
    maxFileChars: typeof maxChars === "number" && maxChars > 0 ? maxChars : 16_000,
  };
}

export function isNoisePath(path: string, patterns: readonly string[]): boolean {
  return patterns.some((pattern) => {
    const subject = pattern.includes("/") ? path : basename(path);

    return matchesGlob(subject, pattern);
  });
}

function renderRequest(files: readonly ReviewFile[], isJudged: (key: string) => boolean) {
  const sections: string[] = [];
  const questions: NoiseRequest["questions"] = [];
  let hunkCount = 0;

  for (const file of files) {
    const hunks = file.hunks.map((hunk) => {
      const name = `h${hunkCount}`;
      hunkCount += 1;
      if (!isJudged(hunk.key)) {
        const instructions = `Is hunk ${name} of ${file.path} noise?`;
        questions.push({ name, instructions, key: hunk.key });
      }

      return `[hunk ${name}]\n${hunk.text}`;
    });

    sections.push(`## File: ${file.path}\n${hunks.join("\n")}`);
  }

  // The criteria come last: stated before the diff, they wrongly hid a hunk in the evaluation.
  const input = `# Diff\n\n${sections.join("\n\n")}\n\n# Task\n\n${NOISE_CRITERIA}`;

  return { input, questions };
}

/**
 * Decide how to judge the hunks that have no verdict yet. Judged hunks are still sent as context:
 * a hunk that follows another can only be recognised next to it.
 */
export function planNoiseRun(
  files: readonly ReviewFile[],
  isJudged: (key: string) => boolean,
  settings: NoiseSettings,
): NoisePlan {
  const unjudgedKeys = (file: ReviewFile) =>
    file.hunks.map((hunk) => hunk.key).filter((key) => !isJudged(key));
  const sizeOf = (file: ReviewFile) =>
    file.hunks.reduce((size, hunk) => size + hunk.text.length, 0);

  const pathNoiseKeys: string[] = [];
  const oversizedKeys: string[] = [];
  const batches: ReviewFile[][] = [];
  let batchSize = 0;
  let batchHunkCount = 0;

  // Files keep the order of the review, which is by path: the files of one directory, where
  // most changes ripple, land in the same request.
  for (const file of files) {
    if (file.hunks.length === 0) continue;

    if (isNoisePath(file.path, settings.paths)) {
      pathNoiseKeys.push(...unjudgedKeys(file));
      continue;
    }

    const size = sizeOf(file);
    if (size > settings.maxFileChars) {
      oversizedKeys.push(...unjudgedKeys(file));
      continue;
    }

    const isBatchFull =
      batchSize + size > MAX_REQUEST_CHARS ||
      batchHunkCount + file.hunks.length > MAX_REQUEST_QUESTIONS;
    if (batches.length === 0 || isBatchFull) {
      batches.push([]);
      batchSize = 0;
      batchHunkCount = 0;
    }

    batches.at(-1)?.push(file);
    batchSize += size;
    batchHunkCount += file.hunks.length;
  }

  const requests = batches
    .map((batch) => renderRequest(batch, isJudged))
    .filter((request) => request.questions.length > 0);

  return { pathNoiseKeys, requests, oversizedKeys };
}
