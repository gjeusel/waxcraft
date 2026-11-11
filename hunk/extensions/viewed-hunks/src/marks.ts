// Viewed marks kept between Hunk runs, as one JSON file of hunk keys and the date each was marked.
//
// Keys carry no repository: a key digests the file path and hunk body, so the same change stays
// viewed wherever it is reviewed, and marks nobody reviews anymore expire.
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join } from "node:path";

export const MARK_TTL_MS = 30 * 24 * 60 * 60 * 1000;

/** Hunk key to the ISO date it was marked viewed. */
type Marks = Record<string, string>;

export interface MarksChange {
  added: readonly string[];
  removed: readonly string[];
}

/** `$XDG_STATE_HOME/hunk/viewed-hunks.json`, beside Hunk's own state file. */
export function resolveMarksPath(env: NodeJS.ProcessEnv, homeDir: string): string {
  const xdgStateHome = env.XDG_STATE_HOME;
  // The XDG specification makes a relative XDG_STATE_HOME invalid.
  const stateHome =
    xdgStateHome && isAbsolute(xdgStateHome) ? xdgStateHome : join(homeDir, ".local", "state");

  return join(stateHome, "hunk", "viewed-hunks.json");
}

/** The unexpired marks on disk; a missing or unusable file holds none. */
function readMarks(path: string, now: Date): Marks {
  let stored: unknown;
  try {
    stored = (JSON.parse(readFileSync(path, "utf8")) as { hunks?: unknown }).hunks;
  } catch {
    return {};
  }

  if (typeof stored !== "object" || stored === null) return {};

  const marks: Marks = {};
  for (const [key, markedAt] of Object.entries(stored)) {
    const isExpired = !(Date.parse(String(markedAt)) >= now.getTime() - MARK_TTL_MS);
    if (!isExpired) marks[key] = String(markedAt);
  }

  return marks;
}

export function loadMarks(path: string, now: Date): Set<string> {
  return new Set(Object.keys(readMarks(path, now)));
}

/** Apply one session's change to the marks on disk, keeping what other sessions wrote. */
export function saveMarks(path: string, change: MarksChange, now: Date): void {
  const marks = readMarks(path, now);
  for (const key of change.added) marks[key] = now.toISOString();
  for (const key of change.removed) delete marks[key];

  mkdirSync(dirname(path), { recursive: true });

  // Rename over the target so a concurrent reader never sees a half-written file.
  const stagedPath = `${path}.${process.pid}.tmp`;
  writeFileSync(stagedPath, `${JSON.stringify({ version: 1, hunks: marks }, null, 2)}\n`);
  renameSync(stagedPath, path);
}
