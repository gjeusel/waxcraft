import { createHash } from "node:crypto";
import type { ExtensionDiffFile, ExtensionLineHighlight } from "hunkdiff/extension";

export interface ParsedHunk {
  /** Digest of the file path and hunk body: stable across reloads, changed by any edit. */
  key: string;
  /** The new-side line the hunk starts at. */
  line: number;
  /** The hunk as the patch spells it: its `@@` header, then its lines. */
  text: string;
  /** One dim mark per non-empty line of the hunk. */
  marks: ExtensionLineHighlight[];
}

/** Split one file patch into its hunks, in the order Hunk indexes them. */
export function parseHunks(file: Pick<ExtensionDiffFile, "path" | "patch">): ParsedHunk[] {
  const hunks: { header: string; line: number; body: string[]; marks: ExtensionLineHighlight[] }[] =
    [];
  let oldLine = 0;
  let newLine = 0;

  for (const raw of file.patch.split("\n")) {
    const header = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(raw);
    if (header) {
      oldLine = Number(header[1]);
      newLine = Number(header[2]);
      hunks.push({ header: raw, line: newLine, body: [], marks: [] });
      continue;
    }

    const hunk = hunks.at(-1);
    const isHunkLine = raw.startsWith("+") || raw.startsWith("-") || raw.startsWith(" ");
    if (!hunk || !isHunkLine) continue;

    hunk.body.push(raw);

    const isRemoved = raw.startsWith("-");
    const line = isRemoved ? oldLine : newLine;
    if (raw.length > 1) {
      const side = isRemoved ? "old" : "new";
      hunk.marks.push({ side, line, range: [0, raw.length - 1], tone: "dim" });
    }

    if (!raw.startsWith("+")) oldLine += 1;
    if (!isRemoved) newLine += 1;
  }

  return hunks.map(({ header, line, body, marks }) => {
    const key = createHash("sha256").update(`${file.path}\n${body.join("\n")}`).digest("hex");

    return { key, line, text: [header, ...body].join("\n"), marks };
  });
}

/**
 * `color` moved towards `background` by `amount` (0 keeps it, 1 reaches the background). Both are
 * `#rrggbb`; any other notation returns `color` unchanged.
 */
export function fade(color: string, background: string, amount: number): string {
  const channels = (hex: string) => /^#([0-9a-f]{6})$/i.exec(hex)?.[1]?.match(/../g);
  const from = channels(color);
  const to = channels(background);
  if (!from || !to) return color;

  const mixed = from.map((channel, index) => {
    const start = parseInt(channel, 16);
    const end = parseInt(to[index] ?? channel, 16);

    return Math.round(start + (end - start) * amount)
      .toString(16)
      .padStart(2, "0");
  });

  return `#${mixed.join("")}`;
}

/** The first of `height` rows to show out of `rowCount`, keeping the selected row mid-window. */
export function windowStart(selectedRow: number, rowCount: number, height: number): number {
  const lastStart = Math.max(0, rowCount - height);

  return Math.min(Math.max(0, selectedRow - Math.floor(height / 2)), lastStart);
}

/**
 * The nearest unviewed hunk after (direction 1) or before (direction -1) position `from`,
 * wrapping at the ends and never returning `from` itself. `from` is -1 when nothing is selected.
 */
export function findUnviewedHunk<Hunk>(
  hunks: readonly Hunk[],
  from: number,
  direction: 1 | -1,
  isViewed: (hunk: Hunk) => boolean,
): Hunk | null {
  const count = hunks.length;
  const start = from >= 0 ? from : direction === 1 ? -1 : count;

  for (let step = 1; step <= count; step += 1) {
    const index = (((start + step * direction) % count) + count) % count;
    const hunk = hunks[index];
    if (hunk !== undefined && index !== from && !isViewed(hunk)) return hunk;
  }

  return null;
}
