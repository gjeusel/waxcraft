// What is known about hunks between Hunk runs, as one JSON file keyed by hunk key: the hunks the
// user viewed, the model's noise verdicts, and the hunks the user kept against such a verdict.
//
// Keys carry no repository: a key digests the file path and hunk body, so the same change keeps
// its marks wherever it is reviewed, and marks nobody reviews anymore expire.
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join } from "node:path";

export const MARK_TTL_MS = 30 * 24 * 60 * 60 * 1000;

export interface Marks {
  /** Hunks the user marked viewed. */
  viewed: Set<string>;
  /** Hunks the user kept on screen although the model judged them noise. */
  kept: Set<string>;
  /** The probability that a hunk is noise, for every hunk that was judged. */
  noise: Map<string, number>;
}

interface KeysChange {
  added?: readonly string[];
  removed?: readonly string[];
}

export interface MarksChange {
  viewed?: KeysChange;
  kept?: KeysChange;
  noise?: { added?: ReadonlyMap<string, number>; removed?: readonly string[] };
}

/** One stored mark: when it was made, and the noise probability for a verdict. */
interface Entry {
  at: string;
  probability?: number;
}

type Section = Record<string, Entry>;

// `hunks` holds the viewed marks: the name predates the other two sections.
const SECTIONS = { viewed: "hunks", kept: "kept", noise: "noise" } as const;

/** `$XDG_STATE_HOME/hunk/viewed-hunks.json`, beside Hunk's own state file. */
export function resolveMarksPath(env: NodeJS.ProcessEnv, homeDir: string): string {
  const xdgStateHome = env.XDG_STATE_HOME;
  // The XDG specification makes a relative XDG_STATE_HOME invalid.
  const stateHome =
    xdgStateHome && isAbsolute(xdgStateHome) ? xdgStateHome : join(homeDir, ".local", "state");

  return join(stateHome, "hunk", "viewed-hunks.json");
}

/** The unexpired entries of every section on disk; a missing or unusable file holds none. */
function readSections(path: string, now: Date): Record<keyof typeof SECTIONS, Section> {
  let stored: Record<string, unknown> = {};
  try {
    const parsed: unknown = JSON.parse(readFileSync(path, "utf8"));
    if (typeof parsed === "object" && parsed !== null) stored = parsed as Record<string, unknown>;
  } catch {
    // Read as empty.
  }

  const readSection = (name: string): Section => {
    const raw = stored[name];
    if (typeof raw !== "object" || raw === null) return {};

    const section: Section = {};
    for (const [key, value] of Object.entries(raw)) {
      // A viewed or kept mark is stored as its bare date.
      const entry: Partial<Entry> = typeof value === "string" ? { at: value } : (value ?? {});
      const isExpired = !(Date.parse(String(entry.at)) >= now.getTime() - MARK_TTL_MS);
      if (!isExpired) section[key] = { at: String(entry.at), probability: entry.probability };
    }

    return section;
  };

  return {
    viewed: readSection(SECTIONS.viewed),
    kept: readSection(SECTIONS.kept),
    noise: readSection(SECTIONS.noise),
  };
}

export function loadMarks(path: string, now: Date): Marks {
  const sections = readSections(path, now);
  const verdicts = Object.entries(sections.noise).flatMap(([key, entry]) =>
    typeof entry.probability === "number" ? [[key, entry.probability] as const] : [],
  );

  return {
    viewed: new Set(Object.keys(sections.viewed)),
    kept: new Set(Object.keys(sections.kept)),
    noise: new Map(verdicts),
  };
}

/** Apply one session's change to the marks on disk, keeping what other sessions wrote. */
export function saveMarks(path: string, change: MarksChange, now: Date): void {
  const sections = readSections(path, now);
  const at = now.toISOString();

  for (const name of ["viewed", "kept"] as const) {
    for (const key of change[name]?.added ?? []) sections[name][key] = { at };
    for (const key of change[name]?.removed ?? []) delete sections[name][key];
  }
  for (const [key, probability] of change.noise?.added ?? []) {
    sections.noise[key] = { at, probability };
  }
  for (const key of change.noise?.removed ?? []) delete sections.noise[key];

  const dates = (section: Section) =>
    Object.fromEntries(Object.entries(section).map(([key, entry]) => [key, entry.at]));
  const content = {
    version: 1,
    [SECTIONS.viewed]: dates(sections.viewed),
    [SECTIONS.kept]: dates(sections.kept),
    [SECTIONS.noise]: sections.noise,
  };

  mkdirSync(dirname(path), { recursive: true });

  // Rename over the target so a concurrent reader never sees a half-written file.
  const stagedPath = `${path}.${process.pid}.tmp`;
  writeFileSync(stagedPath, `${JSON.stringify(content, null, 2)}\n`);
  renameSync(stagedPath, path);
}
