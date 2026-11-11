// Hide the hunks that need no more attention from the review stream: those marked viewed, GitHub
// "Viewed" checkbox style, and those a model judged to be noise (see src/noise.ts).
//
// Hidden hunks leave Hunk's presentation scope, so the built-in hunk and file jumps skip them.
// A hunk is identified by its file path and body, not its index: it stays hidden across reloads
// and Hunk runs for as long as its content is unchanged, and comes back once edited.
import { homedir } from "node:os";
import { useEffect, useSyncExternalStore } from "react";
import type {
  ExtensionCommandContext,
  ExtensionDiffFile,
  ExtensionPaneProps,
  ExtensionReviewPresentationControls,
  HunkExtensionAPI,
} from "hunkdiff/extension";
import { askNoise } from "./src/decisions.ts";
import { findUnviewedHunk, parseHunks, type ParsedHunk } from "./src/hunks.ts";
import { loadMarks, resolveMarksPath, saveMarks, type MarksChange } from "./src/marks.ts";
import { parseNoiseSettings, planNoiseRun, type NoiseSettings } from "./src/noise.ts";

const PANE_ID = "status";
const HIGHLIGHTER_ID = "dim";
const TOGGLE_HIDDEN_COMMAND = "toggle-hidden";

// Hunk rejects a highlighter result above 2,000 ranges per file.
const MAX_MARKS_PER_FILE = 2000;
// Hunk only lets a hunk be selected once it is drawn: leave it a moment after widening the scope.
const REDRAW_DELAY_MS = 50;

interface HunkTarget {
  fileId: string;
  hunkIndex: number;
}

const marksPath = resolveMarksPath(process.env, homedir());

let marks = loadMarks(marksPath, new Date());
let noiseSettings: NoiseSettings = parseNoiseSettings({});
let showHidden = false;
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

function isViewed(key: string) {
  return marks.viewed.has(key);
}

/** Judged noise by the model or a path rule, and neither viewed nor kept by the user since. */
function isNoise(key: string) {
  const probability = marks.noise.get(key);
  const isJudgedNoise = probability !== undefined && probability >= noiseSettings.threshold;

  return isJudgedNoise && !marks.kept.has(key) && !isViewed(key);
}

function isHidden(key: string) {
  return isViewed(key) || isNoise(key);
}

function isTargetHidden(target: HunkTarget) {
  const hunk = hunksByFileId.get(target.fileId)?.[target.hunkIndex];

  return hunk !== undefined && isHidden(hunk.key);
}

/** The keys of the loaded review's hunks; marks of other reviews are left out. */
function reviewKeys() {
  return [...hunksByFileId.values()].flat().map((hunk) => hunk.key);
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
    return;
  }

  controls.setPresentationScope({ generation, files: visibleScopeFiles() });
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

/** The status row stays while it has something to say. */
function syncPane(panes: ExtensionCommandContext["panes"]) {
  const hasMarks = reviewKeys().some((key) => isViewed(key) || marks.noise.has(key));

  if (hasMarks || noiseRun) panes.open(PANE_ID);
  else panes.close(PANE_ID);
}

/** Bring the review in line with the marks after a command changed them. */
function sync(ctx: ExtensionCommandContext) {
  if (isEveryHunkHidden()) ctx.notify("Every hunk is viewed or noise");

  if (isHiding()) {
    const { file, hunkIndex } = ctx.selection;
    const isSelectionHidden =
      file !== null && hunkIndex !== null && isTargetHidden({ fileId: file.id, hunkIndex });
    const next = isSelectionHidden ? findVisibleTarget(ctx, 1) : null;

    // Select before scoping: Hunk sends a selection that falls out of scope back to the top.
    if (next) ctx.navigation.selectHunk(next.fileId, next.hunkIndex);
  }

  syncPane(ctx.panes);
  applyScope(ctx.review, ctx.review.snapshot()?.generation ?? null);
  ctx.highlights.refresh(HIGHLIGHTER_ID);
  publish();
}

function jumpToVisible(ctx: ExtensionCommandContext, direction: 1 | -1) {
  const target = findVisibleTarget(ctx, direction);
  if (!target) {
    ctx.notify(isEveryHunkHidden() ? "Every hunk is viewed or noise" : "No other unviewed hunk");
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
  const isSettled = (key: string) => marks.noise.has(key) || marks.kept.has(key) || isViewed(key);
  const plan = planNoiseRun(reviewFiles, isSettled, noiseSettings);

  const questionCount = plan.requests.reduce((count, r) => count + r.questions.length, 0);
  const apiKey = process.env.OPENAI_API_KEY;
  const verdicts = new Map(plan.pathNoiseKeys.map((key) => [key, 1]));
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
      plan.requests.map((request) => askNoise(request, { apiKey, signal: run.signal })),
    );
    noiseRun = null;

    for (const outcome of outcomes) {
      if (outcome.status === "fulfilled") {
        outcome.value.forEach((probability, key) => verdicts.set(key, probability));
      } else if (!run.signal.aborted) {
        problems.push(String(outcome.reason?.message ?? outcome.reason));
      }
    }

    if (run.signal.aborted) problems.push("cancelled");
  }

  if (plan.oversizedKeys.length > 0) {
    problems.push(`${count(plan.oversizedKeys.length, "hunk")} not judged: file too large`);
  }

  verdicts.forEach((probability, key) => marks.noise.set(key, probability));
  const hiddenCount = [...verdicts.keys()].filter(isNoise).length;

  const uniqueProblems = [...new Set(problems)];
  const outcomes = [...uniqueProblems];
  if (verdicts.size > 0) {
    outcomes.unshift(`Hid ${hiddenCount} of ${count(verdicts.size, "judged hunk")}`);
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
  const noiseCount = keys.filter(isNoise).length;
  const unjudgedCount = keys.filter((key) => !marks.noise.has(key) && !isViewed(key)).length;
  const hasVerdicts = keys.some((key) => marks.noise.has(key));

  const parts = [`${keys.filter(isViewed).length}/${keys.length} viewed`];
  if (noiseCount > 0) parts.push(`${noiseCount} noise`);
  if (noiseRun) parts.push("judging…");
  else if (hasVerdicts && unjudgedCount > 0) parts.push(`${unjudgedCount} not judged`);

  // Hunk offers no way to tag a hunk in the diff, so the row names the selected one.
  const selected = hunksByFileId.get(props.selectedFileId ?? "")?.[props.selectedHunkIndex ?? -1];
  if (selected && isNoise(selected.key)) {
    const probability = marks.noise.get(selected.key) ?? 1;
    parts.push(`this hunk: noise (${probability.toFixed(2)})`);
  } else if (selected && isViewed(selected.key)) {
    parts.push("this hunk: viewed");
  }

  const key = keybindings.getKeys(`viewed-hunks.${TOGGLE_HIDDEN_COMMAND}`)[0];
  const canToggleHidden = key !== undefined && keys.some(isHidden) && !isEveryHunkHidden();
  if (canToggleHidden) parts.push(`${key} to ${isHiding() ? "show" : "hide"} them`);

  return (
    <text content={` ${parts.join(" · ")}`} style={{ fg: theme.muted, bg: theme.panel }} />
  );
}

export default function (hunk: HunkExtensionAPI) {
  noiseSettings = parseNoiseSettings(hunk.config);

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
        ctx.notify("Every hunk is viewed or noise");
        return;
      }

      showHidden = !showHidden;
      sync(ctx);
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
