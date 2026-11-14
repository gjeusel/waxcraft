// Hide the hunks that need no more attention from the review stream: those marked viewed, GitHub
// "Viewed" checkbox style, and those a model judged to be noise (see src/noise.ts).
//
// Hidden hunks leave Hunk's presentation scope, so the built-in hunk and file jumps skip them.
// The model also rates how far each hunk reaches. The architecture view, the default, hides the
// details and keeps the changes of interface and structure; the strict view shows details too.
// A narrow map pane lists every hunk with who settled it, or how far it reaches.
// A hunk is identified by its file path and body, not its index: it stays hidden across reloads
// and Hunk runs for as long as its content is unchanged, and comes back once edited.
import { homedir } from "node:os";
import { basename } from "node:path";
import { useEffect, useSyncExternalStore } from "react";
import type {
  ExtensionCommandContext,
  ExtensionDiffFile,
  ExtensionPaneProps,
  ExtensionReviewPresentationControls,
  HunkExtensionAPI,
} from "hunkdiff/extension";
import { askQuestions } from "./src/decisions.ts";
import { fade, findUnviewedHunk, parseHunks, windowStart } from "./src/hunks.ts";
import type { ParsedHunk } from "./src/hunks.ts";
import { loadMarks, resolveMarksPath, saveMarks, type MarksChange } from "./src/marks.ts";
import { parseNoiseSettings, planNoiseRun, reachOf, toVerdict } from "./src/noise.ts";
import type { NoiseSettings, Reach, Verdict } from "./src/noise.ts";

const PANE_ID = "status";
const MAP_PANE_ID = "map";
const HIGHLIGHTER_ID = "dim";
const TOGGLE_HIDDEN_COMMAND = "toggle-hidden";
const TOGGLE_DETAILS_COMMAND = "toggle-details";

// Hunk rejects a highlighter result above 2,000 ranges per file.
const MAX_MARKS_PER_FILE = 2000;
// How far the map fades a noise hunk towards the background: it is hidden from the diff anyway.
const NOISE_FADE = 0.5;
// From this probability up, a noise verdict is shown as sure.
const SURE_NOISE = 0.98;
// Hunk only lets a hunk be selected once it is drawn: leave it a moment after widening the scope.
const REDRAW_DELAY_MS = 50;

/**
 * What the map shows for a hunk; `noise?` is a noise verdict the model was less sure of, and
 * `oversized` a hunk hidden unread because its file is too large to send.
 */
type HunkStatus = "viewed" | "noise" | "noise?" | "oversized" | Reach | "unjudged";

interface HunkTarget {
  fileId: string;
  hunkIndex: number;
}

const marksPath = resolveMarksPath(process.env, homedir());

let marks = loadMarks(marksPath, new Date());
let noiseSettings: NoiseSettings = parseNoiseSettings({});
let showHidden = false;
/** The strict view shows details too; the architecture view, the default, hides them. */
let showDetails = false;
let showMap = true;
/** Whether Hunk currently shows only part of the review. */
let isScoped = false;
let files: readonly ExtensionDiffFile[] = [];
let hunksByFileId = new Map<string, ParsedHunk[]>();
/** The noise run in flight, if any. */
let noiseRun: AbortController | null = null;
/** The hunks each `x` or `X` marked viewed in this session, oldest first, for undo. */
const viewedHistory: (readonly string[])[] = [];

let version = 0;
const listeners = new Set<() => void>();

function subscribe(listener: () => void) {
  listeners.add(listener);

  return () => listeners.delete(listener);
}

function publish() {
  version += 1;
  listeners.forEach((listener) => listener());
}

/** "1 hunk", "3 hunks". */
function count(quantity: number, noun: string) {
  return `${quantity} ${noun}${quantity === 1 ? "" : "s"}`;
}

/** The keys of the loaded review's hunks; marks of other reviews are left out. */
function reviewKeys() {
  return [...hunksByFileId.values()].flat().map((hunk) => hunk.key);
}

function isViewed(key: string) {
  return marks.viewed.has(key);
}

/** Judged noise by the model or a path rule, and neither viewed nor kept by the user since. */
function isNoise(key: string) {
  const verdict = marks.noise.get(key);
  const isJudgedNoise = verdict !== undefined && verdict.noise >= noiseSettings.threshold;

  return isJudgedNoise && !marks.kept.has(key) && !isViewed(key);
}

/** Hidden like noise, but unread: its file has too much changed text to send to the model. */
function isOversized(key: string) {
  return isNoise(key) && marks.noise.get(key)?.oversized === true;
}

/** Judged to stay inside a body; a hunk the user kept against a noise verdict is never one. */
function isDetail(key: string) {
  const verdict = marks.noise.get(key);
  const isJudgedDetail = verdict !== undefined && reachOf(verdict) === "detail";

  return isJudgedDetail && !isNoise(key) && !marks.kept.has(key) && !isViewed(key);
}

function isHidden(key: string) {
  return isViewed(key) || isNoise(key) || (!showDetails && isDetail(key));
}

/** A verdict made before hunks had a reach is only complete when it says noise. */
function isJudged(key: string) {
  const verdict = marks.noise.get(key);
  if (!verdict) return false;

  return verdict.noise >= noiseSettings.threshold || reachOf(verdict) !== null;
}

/** Who settled the hunk, or how far the model found it to reach when it is left to review. */
function hunkStatus(key: string): HunkStatus {
  if (isViewed(key)) return "viewed";

  const verdict = marks.noise.get(key);
  if (!verdict) return "unjudged";
  if (isOversized(key)) return "oversized";
  if (isNoise(key)) return verdict.noise >= SURE_NOISE ? "noise" : "noise?";

  return reachOf(verdict) ?? "unjudged";
}

/** Why nothing is left on screen; in the architecture view, details may still wait. */
function allHiddenMessage() {
  const detailCount = reviewKeys().filter(isDetail).length;
  if (showDetails || detailCount === 0) return "Every hunk is viewed or noise";

  return `No change of interface or structure left · ${count(detailCount, "detail")} remain`;
}

function isTargetHidden(target: HunkTarget) {
  const hunk = hunksByFileId.get(target.fileId)?.[target.hunkIndex];

  return hunk !== undefined && isHidden(hunk.key);
}

/**
 * Cycle one hunk: a noise hunk is kept on screen, a visible hunk is marked viewed, and a viewed
 * hunk comes back. A hunk that comes back is kept, so that a noise verdict never hides it again.
 */
function toggleHunk(key: string): MarksChange {
  if (isViewed(key)) {
    marks.viewed.delete(key);
    if (!marks.noise.has(key)) return { viewed: { removed: [key] } };

    marks.kept.add(key);

    return { viewed: { removed: [key] }, kept: { added: [key] } };
  }

  if (isNoise(key)) {
    marks.kept.add(key);

    return { kept: { added: [key] } };
  }

  marks.viewed.add(key);

  return { viewed: { added: [key] } };
}

/** Mark the given hunks viewed, or unmark them when they all already are. */
function toggleViewed(keys: readonly string[]): MarksChange {
  const allViewed = keys.every(isViewed);
  for (const key of keys) {
    if (allViewed) marks.viewed.delete(key);
    else marks.viewed.add(key);
  }

  return { viewed: allViewed ? { removed: keys } : { added: keys } };
}

/** Save a change made by `x` or `X`, remembering what it marked viewed so that it can be undone. */
function commitToggle(change: MarksChange) {
  const added = change.viewed?.added ?? [];
  if (added.length > 0) viewedHistory.push(added);

  saveMarks(marksPath, change, new Date());
}

/** The hunks to keep on screen, per file; empty when every hunk is hidden. */
function visibleScopeFiles() {
  return files.flatMap((file) => {
    const hunks = hunksByFileId.get(file.id) ?? [];
    const hunkIndexes = hunks.flatMap((hunk, index) => (isHidden(hunk.key) ? [] : [index]));

    return hunkIndexes.length > 0 ? [{ fileId: file.id, hunkIndexes }] : [];
  });
}

function isEveryHunkHidden() {
  const keys = reviewKeys();

  return keys.length > 0 && keys.every(isHidden);
}

/** Hunk has no empty scope, so a fully hidden review is shown whole, dimmed. */
function isHiding() {
  return !showHidden && reviewKeys().some(isHidden) && !isEveryHunkHidden();
}

function applyScope(controls: ExtensionReviewPresentationControls, generation: string | null) {
  if (!isHiding() || !generation) {
    controls.clearPresentationScope();
    isScoped = false;
    return;
  }

  controls.setPresentationScope({ generation, files: visibleScopeFiles() });
  isScoped = true;
}

/** The nearest visible hunk in the given direction from the selected one, wrapping. */
function findVisibleTarget(ctx: ExtensionCommandContext, direction: 1 | -1): HunkTarget | null {
  const { file, hunkIndex } = ctx.selection;
  const targets = ctx.selection.files.flatMap((candidate) =>
    (candidate.hunks ?? []).map((hunk) => ({ fileId: candidate.id, hunkIndex: hunk.index })),
  );
  const selected = targets.findIndex(
    (target) => target.fileId === file?.id && target.hunkIndex === hunkIndex,
  );

  return findUnviewedHunk(targets, selected, direction, isTargetHidden);
}

/** The status row and the map stay while they have something to say. */
function syncPane(panes: ExtensionCommandContext["panes"]) {
  const hasMarks = reviewKeys().some((key) => isViewed(key) || marks.noise.has(key));

  if (hasMarks || noiseRun) panes.open(PANE_ID);
  else panes.close(PANE_ID);

  if (hasMarks && showMap) panes.open(MAP_PANE_ID);
  else panes.close(MAP_PANE_ID);
}

/** Bring the review in line with the marks after a command changed them. */
function sync(ctx: ExtensionCommandContext) {
  if (isEveryHunkHidden()) ctx.notify(allHiddenMessage());

  if (isHiding()) {
    const { file, hunkIndex } = ctx.selection;
    const isSelectionHidden =
      file !== null && hunkIndex !== null && isTargetHidden({ fileId: file.id, hunkIndex });
    const next = isSelectionHidden ? findVisibleTarget(ctx, 1) : null;

    // Select before scoping: Hunk sends a selection that falls out of scope back to the top.
    if (next) ctx.navigation.selectHunk(next.fileId, next.hunkIndex);
  }

  const wasScoped = isScoped;
  const { file, hunkIndex } = ctx.selection;

  syncPane(ctx.panes);
  applyScope(ctx.review, ctx.review.snapshot()?.generation ?? null);
  ctx.highlights.refresh(HIGHLIGHTER_ID);
  publish();

  // Hunk scrolls back to the top when the hidden hunks return: go back to the selected one.
  if (wasScoped && !isScoped && file !== null && hunkIndex !== null) {
    setTimeout(() => ctx.navigation.selectHunk(file.id, hunkIndex), REDRAW_DELAY_MS);
  }
}

function jumpToVisible(ctx: ExtensionCommandContext, direction: 1 | -1) {
  const target = findVisibleTarget(ctx, direction);
  if (!target) {
    ctx.notify(isEveryHunkHidden() ? allHiddenMessage() : "No other unviewed hunk");
    return;
  }

  ctx.navigation.selectHunk(target.fileId, target.hunkIndex);
}

/**
 * Judge the hunks that have no verdict yet and hide the noise among them. Nothing leaves the
 * machine before this command is run; running it again while it works cancels it.
 */
async function hideNoise(ctx: ExtensionCommandContext) {
  if (noiseRun) {
    noiseRun.abort();
    return;
  }

  const reviewFiles = files.map((file) => ({
    path: file.path,
    hunks: hunksByFileId.get(file.id) ?? [],
  }));
  // An oversized hunk is checked again on each run: the limit is a setting that can be raised.
  const isSettled = (key: string) => {
    const isRecheckable = marks.noise.get(key)?.oversized === true;

    return (isJudged(key) && !isRecheckable) || marks.kept.has(key) || isViewed(key);
  };
  const plan = planNoiseRun(reviewFiles, isSettled, noiseSettings);

  const sentKeys = plan.requests.flatMap((request) => request.questions.map((q) => q.key));
  const questionCount = new Set(sentKeys).size;
  const apiKey = process.env.OPENAI_API_KEY;
  const verdicts = new Map<string, Verdict>(plan.pathNoiseKeys.map((key) => [key, { noise: 1 }]));
  const problems: string[] = [];

  if (questionCount > 0 && !apiKey) {
    problems.push("OPENAI_API_KEY is not set, nothing was sent");
  } else if (questionCount > 0 && apiKey) {
    const run = new AbortController();
    noiseRun = run;
    ctx.notify(`Judging ${count(questionCount, "hunk")} with OpenAI · run again to cancel`);
    syncPane(ctx.panes);
    publish();

    const outcomes = await Promise.allSettled(
      plan.requests.map((request) => askQuestions(request, { apiKey, signal: run.signal })),
    );
    noiseRun = null;

    for (const outcome of outcomes) {
      if (outcome.status === "fulfilled") {
        for (const [key, answers] of outcome.value) {
          const verdict = toVerdict(answers);
          if (verdict) verdicts.set(key, verdict);
        }
      } else if (!run.signal.aborted) {
        problems.push(String(outcome.reason?.message ?? outcome.reason));
      }
    }

    if (run.signal.aborted) problems.push("cancelled");
  }

  const newlyOversized = plan.oversizedKeys.filter((key) => !marks.noise.get(key)?.oversized);
  for (const key of plan.oversizedKeys) verdicts.set(key, { noise: 1, oversized: true });

  verdicts.forEach((verdict, key) => marks.noise.set(key, verdict));
  const judgedKeys = [...verdicts.keys()].filter((key) => !plan.oversizedKeys.includes(key));
  const noiseCount = judgedKeys.filter(isNoise).length;
  const detailCount = judgedKeys.filter(isDetail).length;

  const uniqueProblems = [...new Set(problems)];
  const outcomes = [...uniqueProblems];
  if (newlyOversized.length > 0) {
    outcomes.unshift(`${count(newlyOversized.length, "hunk")} hidden unread: file too large`);
  }
  if (judgedKeys.length > 0) {
    const judged = `Judged ${count(judgedKeys.length, "hunk")}`;
    outcomes.unshift(`${judged}: ${noiseCount} noise, ${count(detailCount, "detail")}`);
  }
  if (outcomes.length === 0) outcomes.push("No hunk left to judge");

  ctx.notify(outcomes.join(" · "), uniqueProblems.length > 0 ? "warning" : "info");

  sync(ctx);
  if (verdicts.size > 0) saveMarks(marksPath, { noise: { added: verdicts } }, new Date());
}

/** One progress row; its mount is also what re-applies the scope after a reload dropped it. */
function StatusPane(props: ExtensionPaneProps) {
  const { actions, keybindings, reviewGeneration, theme } = props;
  const currentVersion = useSyncExternalStore(subscribe, () => version);

  useEffect(() => {
    applyScope(actions, reviewGeneration);
  }, [actions, currentVersion, reviewGeneration]);

  const keys = reviewKeys();
  const oversizedCount = keys.filter(isOversized).length;
  const noiseCount = keys.filter(isNoise).length - oversizedCount;
  const detailCount = keys.filter(isDetail).length;
  const unjudgedCount = keys.filter((key) => !isJudged(key) && !isViewed(key)).length;
  const hasVerdicts = keys.some((key) => marks.noise.has(key));

  const parts = [`${keys.filter(isViewed).length}/${keys.length} viewed`];
  if (noiseCount > 0) parts.push(`${noiseCount} noise`);
  if (detailCount > 0) parts.push(count(detailCount, "detail"));
  if (oversizedCount > 0) parts.push(`${oversizedCount} oversized`);
  if (noiseRun) parts.push("judging…");
  else if (hasVerdicts && unjudgedCount > 0) parts.push(`${unjudgedCount} not judged`);

  // The map names each hunk's status; the row adds the probability behind a noise verdict.
  const selected = hunksByFileId.get(props.selectedFileId ?? "")?.[props.selectedHunkIndex ?? -1];
  const verdict = marks.noise.get(selected?.key ?? "");
  const reach = verdict ? reachOf(verdict) : null;
  if (selected && isViewed(selected.key)) {
    parts.push("this hunk: viewed by you");
  } else if (selected && isOversized(selected.key)) {
    parts.push("this hunk: oversized, not read by the model");
  } else if (selected && verdict && isNoise(selected.key)) {
    parts.push(`this hunk: noise (${verdict.noise.toFixed(2)})`);
  } else if (reach) {
    parts.push(`this hunk: ${reach}`);
  }

  const detailsKey = keybindings.getKeys(`viewed-hunks.${TOGGLE_DETAILS_COMMAND}`)[0];
  if (hasVerdicts) {
    const hint = detailsKey === undefined ? "" : ` (${detailsKey})`;
    parts.push(`${showDetails ? "strict" : "architecture"} view${hint}`);
  }

  const key = keybindings.getKeys(`viewed-hunks.${TOGGLE_HIDDEN_COMMAND}`)[0];
  const canToggleHidden = key !== undefined && keys.some(isHidden) && !isEveryHunkHidden();
  if (canToggleHidden) parts.push(`${key} to ${isHiding() ? "show" : "hide"} them`);

  return (
    <text content={` ${parts.join(" · ")}`} style={{ fg: theme.muted, bg: theme.panel }} />
  );
}

/** Every hunk of the review, one row each under its file, with its status. */
function MapPane({ selectedFileId, selectedHunkIndex, width, height, theme }: ExtensionPaneProps) {
  useSyncExternalStore(subscribe, () => version);

  // A transparent background names no colour to fade towards: assume the terminal's is plain.
  const isOpaque = theme.background.startsWith("#");
  const plain = theme.appearance === "dark" ? "#000000" : "#ffffff";
  const background = isOpaque ? theme.background : plain;
  const faded = (color: string) => fade(color, background, NOISE_FADE);
  const looks: Record<HunkStatus, { glyph: string; color: string }> = {
    viewed: { glyph: "◆", color: theme.badgeAdded },
    noise: { glyph: "●", color: faded(theme.muted) },
    "noise?": { glyph: "●", color: faded(theme.fileModified) },
    oversized: { glyph: "■", color: faded(theme.muted) },
    // A detail recedes like noise while the architecture view hides it.
    detail: { glyph: "○", color: showDetails ? theme.text : faded(theme.text) },
    interface: { glyph: "▲", color: theme.fileModified },
    structure: { glyph: "▲", color: theme.badgeRemoved },
    unjudged: { glyph: "·", color: theme.muted },
  };

  const rows: { text: string; color: string }[] = [];
  let selectedRow = -1;
  for (const file of files) {
    const hunks = hunksByFileId.get(file.id) ?? [];
    if (hunks.length === 0) continue;

    rows.push({ text: ` ${basename(file.path)}`, color: theme.text });
    for (const [hunkIndex, hunk] of hunks.entries()) {
      const isSelected = file.id === selectedFileId && hunkIndex === selectedHunkIndex;
      if (isSelected) selectedRow = rows.length;

      const status = hunkStatus(hunk.key);
      const { glyph, color } = looks[status];
      const label = status === "unjudged" ? "" : status;
      const line = String(hunk.line).padStart(4);
      rows.push({ text: ` ${isSelected ? "▶" : " "} ${glyph}${line} ${label}`, color });
    }
  }

  // The pane cannot follow the diff's scroll position, only its selection.
  const start = windowStart(selectedRow, rows.length, height);

  return (
    <box style={{ flexDirection: "column", width, height, backgroundColor: theme.panel }}>
      {rows.slice(start, start + height).map((row, index) => (
        <text
          key={start + index}
          content={row.text.slice(0, width)}
          style={{
            fg: row.color,
            bg: start + index === selectedRow ? theme.panelAlt : theme.panel,
          }}
        />
      ))}
    </box>
  );
}

export default function (hunk: HunkExtensionAPI) {
  noiseSettings = parseNoiseSettings(hunk.config);

  hunk.registerPane({
    id: MAP_PANE_ID,
    title: "Hunk map",
    placement: "right",
    width: { preferred: 22, min: 16, max: 40 },
    component: MapPane,
  });

  hunk.registerPane({
    id: PANE_ID,
    title: "Viewed hunks",
    placement: "bottom",
    height: { preferred: 1, min: 1, max: 1 },
    component: StatusPane,
  });

  hunk.registerLineHighlighter({
    id: HIGHLIGHTER_ID,
    highlight({ file }) {
      const dimMarks = parseHunks(file)
        .filter((parsed) => isHidden(parsed.key))
        .flatMap((parsed) => parsed.marks);

      return dimMarks.slice(0, MAX_MARKS_PER_FILE);
    },
  });

  hunk.on("changeset_loaded", ({ changeset }, ctx) => {
    // Every change is saved at once, so the file also carries what other sessions marked.
    marks = loadMarks(marksPath, new Date());
    files = changeset.files;
    hunksByFileId = new Map(files.map((file) => [file.id, parseHunks(file)]));

    syncPane(ctx.panes);
    publish();
  });

  hunk.registerCommand(
    { id: "toggle-hunk", title: "Toggle selected hunk viewed", key: "x" },
    (ctx) => {
      const { file, hunkIndex } = ctx.selection;
      const selected = hunksByFileId.get(file?.id ?? "")?.[hunkIndex ?? -1];
      if (!selected) return;

      const change = toggleHunk(selected.key);
      sync(ctx);
      commitToggle(change);
    },
  );

  hunk.registerCommand(
    { id: "toggle-file", title: "Toggle selected file viewed", key: "X" },
    (ctx) => {
      const fileHunks = hunksByFileId.get(ctx.selection.file?.id ?? "") ?? [];
      if (fileHunks.length === 0) return;

      const change = toggleViewed(fileHunks.map((parsed) => parsed.key));
      sync(ctx);
      commitToggle(change);
    },
  );

  hunk.registerCommand(
    { id: "undo-viewed", title: "Undo the last mark as viewed", key: "u" },
    async (ctx) => {
      // Skip what was unmarked by hand since: undoing it would change nothing.
      let undone: string[] = [];
      while (undone.length === 0 && viewedHistory.length > 0) {
        undone = (viewedHistory.pop() ?? []).filter(isViewed);
      }

      if (undone.length === 0) {
        ctx.notify("Nothing to undo");
        return;
      }

      for (const key of undone) marks.viewed.delete(key);
      sync(ctx);
      saveMarks(marksPath, { viewed: { removed: undone } }, new Date());

      // Go back to where the mark was made; a noise hunk it covered is hidden again.
      await new Promise((resolve) => setTimeout(resolve, REDRAW_DELAY_MS));
      for (const file of files) {
        const hunkIndex = (hunksByFileId.get(file.id) ?? []).findIndex(
          (parsed) => undone.includes(parsed.key) && !isHidden(parsed.key),
        );
        if (hunkIndex < 0) continue;

        ctx.navigation.selectHunk(file.id, hunkIndex);
        break;
      }
    },
  );

  hunk.registerCommand(
    { id: "next-unviewed", title: "Next unviewed hunk", key: ">" },
    (ctx) => jumpToVisible(ctx, 1),
  );

  hunk.registerCommand(
    { id: "previous-unviewed", title: "Previous unviewed hunk", key: "<" },
    (ctx) => jumpToVisible(ctx, -1),
  );

  hunk.registerCommand(
    { id: "hide-noise", title: "Hide noise hunks (sends the diff to OpenAI)", key: "T" },
    hideNoise,
  );

  hunk.registerCommand(
    { id: TOGGLE_HIDDEN_COMMAND, title: "Show or hide viewed and noise hunks", key: "H" },
    (ctx) => {
      if (!reviewKeys().some(isHidden)) {
        ctx.notify("No viewed or noise hunk yet");
        return;
      }

      // Nothing can be hidden then, so a flip would only surprise once a hunk comes back.
      if (isEveryHunkHidden()) {
        ctx.notify(allHiddenMessage());
        return;
      }

      showHidden = !showHidden;
      sync(ctx);
    },
  );

  hunk.registerCommand(
    {
      id: TOGGLE_DETAILS_COMMAND,
      title: "Switch between the architecture and strict views",
      key: "d",
    },
    (ctx) => {
      if (!reviewKeys().some((key) => marks.noise.has(key))) {
        ctx.notify("No hunk is judged yet: hide noise first");
        return;
      }

      showDetails = !showDetails;
      const detailCount = reviewKeys().filter(isDetail).length;
      const details = count(detailCount, "detail");
      ctx.notify(
        showDetails ? `Strict view: ${details} shown` : `Architecture view: ${details} hidden`,
      );
      sync(ctx);
    },
  );

  hunk.registerCommand(
    { id: "toggle-map", title: "Show or hide the hunk map", key: "o" },
    (ctx) => {
      showMap = !showMap;
      syncPane(ctx.panes);
    },
  );

  hunk.registerCommand(
    { id: "clear", title: "Clear viewed and noise marks of this review" },
    async (ctx) => {
      const keys = reviewKeys();
      const viewed = keys.filter(isViewed);
      const kept = keys.filter((key) => marks.kept.has(key));
      const judged = keys.filter((key) => marks.noise.has(key));
      if (viewed.length + kept.length + judged.length === 0) {
        ctx.notify("No viewed or noise hunk yet");
        return;
      }

      const viewedMarks = count(viewed.length, "viewed mark");
      const isConfirmed = await ctx.dialogs.confirm({
        title: `Clear ${viewedMarks} and ${count(judged.length, "noise verdict")}?`,
        body: "Every hunk of this review becomes unviewed and unjudged again.",
        confirmLabel: "clear",
      });
      if (!isConfirmed) return;

      for (const key of keys) {
        marks.viewed.delete(key);
        marks.kept.delete(key);
        marks.noise.delete(key);
      }

      sync(ctx);
      saveMarks(
        marksPath,
        { viewed: { removed: viewed }, kept: { removed: kept }, noise: { removed: judged } },
        new Date(),
      );
    },
  );
}
