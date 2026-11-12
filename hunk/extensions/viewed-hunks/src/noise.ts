// What a noise hunk is, and how a review is turned into Decisions API requests asking for it.
//
// A noise hunk is one a reviewer can verify at a glance. Lockfile-like paths are noise by rule;
// every other hunk is judged by the model, which sees the whole diff so that it can tell the
// origin of a change from the hunks that only follow it. Moved code is never noise: the model
// cannot tell an unchanged move from an edited one.
//
// Each hunk gets four yes/no questions: whether it is noise, whether it only changes imports (the
// noise question alone leaves most import hunks on screen), whether it adds or removes a whole
// definition, and whether it changes an existing signature. The last two give its reach, which the
// architecture view filters on: it shows the changes of interface and structure, not the details.
// One graded question for the reach was tried first: its answers moved too much with the wording.
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

// Each hunk is sent three times, once in the diff and once in each of its two reach questions:
// this keeps a request around 75k tokens.
const MAX_REQUEST_CHARS = 100_000;
// The Decisions API accepts at most 400 questions per request.
const MAX_REQUEST_QUESTIONS = 400;
const QUESTIONS_PER_HUNK = 4;
// Enough for a file with dozens of hunks; a regenerated snapshot or a recorded cassette is larger.
const DEFAULT_MAX_FILE_CHARS = 64_000;

/** Re-run `npm run eval:noise` before changing this wording. */
export const NOISE_CRITERIA = `You help a code reviewer skip noise. The diff above is split into files and hunks. Each hunk is introduced by a line such as \`[hunk h3]\`.

A hunk is NOISE when a reviewer can verify it at a glance, without reasoning about new behavior. That is a hunk which only:
- follows a change made in another hunk of this diff: a call site, import, test, comment or doc updated for a rename or a changed signature
- reformats, rewraps or reorders code (imports, members, keys, definitions) without changing its content
- moves an entry of a manifest or a configuration file to another place without changing its value, including the commas or brackets that have to follow it
- adds or edits a comment beside changes that are all noise: an import with a comment about it, a call site following a rename with a reworded comment
- deletes something another hunk made useless
- fixes a typo, or updates a comment or doc to match a name or value changed elsewhere
- adds or adjusts type annotations without changing what callers may pass or receive
- rewords a log, error or user-facing message without changing when it is emitted
- changes a generated file in a way that carries no meaning: timestamps, hashes, ids, ordering

A hunk is NOT noise when it:
- adds, removes or changes logic, behavior, a default, a constant or a setting, however small
- is the origin other hunks follow: the renamed definition, the changed signature
- removes code on its own: a function, a branch, a check, a feature
- adds a new test or new assertions
- adds or rewrites a comment, a docstring or documentation on code that this hunk leaves unchanged or changes for real
- changes what a manifest or a configuration file sets (dependencies, build, CI, lint, settings): a value, a version, an option, an entry added or removed
- moves a block of code to another place, edited or not: neither the place it leaves nor the place it arrives is noise
- changes a snapshot or a generated API schema in a way that reflects a real change of output or contract

Read the whole diff before judging a hunk: the change it follows can be in any file, before or after it.

When in doubt, the hunk is not noise.`;

/** Re-run `npm run eval:noise` before changing this wording. */
const IMPORTS_QUESTION = `change nothing but import statements? Look only at its lines starting with + or -, and ignore the unchanged lines around them. Answer yes when every one of those lines is blank, a comment, or an import of names (import, from … import, require, use, include) at the top level of the file, and at least one is an import. Answer no when any of them is something else, when an import is placed inside a function or a condition, or when a module is imported only for its side effects.`;

/** Re-run `npm run eval:noise` before changing this wording. */
const STRUCTURE_QUESTION = `add, remove or move a whole definition, outside of test files? Look only at its lines starting with + or -. Answer yes when a complete function, method, class, component, route or command appears or disappears among them: the line that opens it (def, function, class, a method header, a route or command registration) is itself added or removed, together with its body. Answer yes too when the code of the hunk starts calling another module of the project that this file did not use before. Answer no when the opening line of a definition is only edited (renamed, new parameters), and when the hunk only changes lines inside definitions that already exist, import statements, constants, the fields of a type, comments, configuration or tests.`;

/** Re-run `npm run eval:noise` before changing this wording. */
const INTERFACE_QUESTION = `change what callers see of something that already exists? Look only at its lines starting with + or -. Answer yes when the hunk changes the name, the parameters or the return type of a function or method that already exists, or the path, the arguments or the payload of a route, a command or an API schema. Answer no when it only changes bodies, import statements, constants, the fields of a type, comments, configuration or tests, and no for a call site that merely follows a signature changed in another hunk.`;

export type QuestionKind = "noise" | "imports" | "structure" | "interface";

/** The probability the model gave to each question about one hunk. */
export type HunkAnswers = Partial<Record<QuestionKind, number>>;

export interface Verdict {
  /** The probability that the hunk is noise. */
  noise: number;
  /** The probability that it adds, removes or moves a whole definition; absent for path noise. */
  structure?: number;
  /** The probability that it changes what callers see of an existing definition. */
  interface?: number;
}

/** How far a change reaches: inside a body, to what callers see, or to the code's organisation. */
export type Reach = "detail" | "interface" | "structure";

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
  questions: { name: string; key: string; kind: QuestionKind; body: Record<string, unknown> }[];
}

export interface NoisePlan {
  /** Keys of unjudged hunks in files that are noise by path. */
  pathNoiseKeys: string[];
  requests: NoiseRequest[];
  /** Keys of unjudged hunks left out because their file is too large, in text or in hunks. */
  oversizedKeys: string[];
}

/** Read `[extension.viewed-hunks]`. A reviewed repository can set it: keep values in bounds. */
export function parseNoiseSettings(config: Record<string, unknown>): NoiseSettings {
  const { noise_threshold: threshold, noise_paths: paths, noise_max_file_chars: maxChars } = config;
  const extraPaths = Array.isArray(paths) ? paths.filter((path) => typeof path === "string") : [];

  return {
    threshold: typeof threshold === "number" ? Math.min(Math.max(threshold, 0.5), 1) : 0.9,
    paths: [...DEFAULT_NOISE_PATHS, ...extraPaths],
    maxFileChars: typeof maxChars === "number" && maxChars > 0 ? maxChars : DEFAULT_MAX_FILE_CHARS,
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
        const subject = `hunk ${name} of ${file.path}`;
        const ask = (kind: QuestionKind, body: Record<string, unknown>) =>
          questions.push({ name: `${name}.${kind}`, key: hunk.key, kind, body });

        ask("noise", { type: "predicate", instructions: `Is ${subject} noise?` });
        ask("imports", { type: "predicate", instructions: `Does ${subject} ${IMPORTS_QUESTION}` });
        // These two are judged on the hunk alone, which is repeated in the question: asked to
        // find it in a long diff, the model missed most new functions of a real review.
        const repeated = `\n\nHere is ${subject} again:\n\n${hunk.text}`;
        ask("structure", {
          type: "predicate",
          instructions: `Does ${subject} ${STRUCTURE_QUESTION}${repeated}`,
        });
        ask("interface", {
          type: "predicate",
          instructions: `Does ${subject} ${INTERFACE_QUESTION}${repeated}`,
        });
      }

      return `[hunk ${name}]\n${hunk.text}`;
    });

    sections.push(`## File: ${file.path}\n${hunks.join("\n")}`);
  }

  // The criteria come last: stated before the diff, they wrongly hid a hunk in the evaluation.
  const input = `# Diff\n\n${sections.join("\n\n")}\n\n# Task\n\n${NOISE_CRITERIA}`;

  return { input, questions };
}

/** A hunk that only changes imports is noise, however the noise question was answered. */
export function toVerdict(answers: HunkAnswers): Verdict | null {
  if (answers.noise === undefined) return null;

  return {
    noise: Math.max(answers.noise, answers.imports ?? 0),
    structure: answers.structure,
    interface: answers.interface,
  };
}

/** The furthest level the model leaned towards; a hunk it was not asked about has none. */
export function reachOf(verdict: Verdict): Reach | null {
  if (verdict.structure === undefined && verdict.interface === undefined) return null;
  if ((verdict.structure ?? 0) >= 0.5) return "structure";

  return (verdict.interface ?? 0) >= 0.5 ? "interface" : "detail";
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
    const isOversized =
      size > settings.maxFileChars ||
      file.hunks.length * QUESTIONS_PER_HUNK > MAX_REQUEST_QUESTIONS;
    if (isOversized) {
      oversizedKeys.push(...unjudgedKeys(file));
      continue;
    }

    const isBatchFull =
      batchSize + size > MAX_REQUEST_CHARS ||
      (batchHunkCount + file.hunks.length) * QUESTIONS_PER_HUNK > MAX_REQUEST_QUESTIONS;
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
