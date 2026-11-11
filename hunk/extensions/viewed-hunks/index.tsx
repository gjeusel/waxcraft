// Mark hunks as viewed to hide them from the review stream, GitHub "Viewed" checkbox style.
//
// Hidden hunks leave Hunk's presentation scope, so the built-in hunk and file jumps skip them.
// A viewed hunk is identified by its file path and body, not its index: it stays hidden across
// reloads and Hunk runs for as long as its content is unchanged, and comes back once edited.
import { homedir } from "node:os";
import { useEffect, useSyncExternalStore } from "react";
import type {
  ExtensionCommandContext,
  ExtensionDiffFile,
  ExtensionPaneProps,
  ExtensionReviewPresentationControls,
  HunkExtensionAPI,
} from "hunkdiff/extension";
import { findUnviewedHunk, parseHunks, type ParsedHunk } from "./src/hunks.ts";
import { loadMarks, resolveMarksPath, saveMarks, type MarksChange } from "./src/marks.ts";

const PANE_ID = "status";
const HIGHLIGHTER_ID = "dim";
const TOGGLE_HIDDEN_COMMAND = "toggle-hidden";

// Hunk rejects a highlighter result above 2,000 ranges per file.
const MAX_MARKS_PER_FILE = 2000;

interface HunkTarget {
  fileId: string;
  hunkIndex: number;
}

const marksPath = resolveMarksPath(process.env, homedir());

let viewedKeys = loadMarks(marksPath, new Date());
let showViewed = false;
let files: readonly ExtensionDiffFile[] = [];
let hunksByFileId = new Map<string, ParsedHunk[]>();

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

function isViewed(target: HunkTarget) {
  const hunk = hunksByFileId.get(target.fileId)?.[target.hunkIndex];

  return hunk !== undefined && viewedKeys.has(hunk.key);
}

/** Mark the given hunks viewed, or unmark them when they all already are. */
function toggleViewed(keys: readonly string[]): MarksChange {
  const allViewed = keys.every((key) => viewedKeys.has(key));
  for (const key of keys) {
    if (allViewed) viewedKeys.delete(key);
    else viewedKeys.add(key);
  }

  return allViewed ? { added: [], removed: keys } : { added: keys, removed: [] };
}

/** The viewed marks of the loaded review; marks of other reviews are left out. */
function viewedKeysInReview() {
  const keys = [...hunksByFileId.values()].flat().map((hunk) => hunk.key);

  return keys.filter((key) => viewedKeys.has(key));
}

/** The hunks to keep on screen, per file; empty when every hunk is viewed. */
function unviewedScopeFiles() {
  return files.flatMap((file) => {
    const hunks = hunksByFileId.get(file.id) ?? [];
    const hunkIndexes = hunks.flatMap((hunk, index) => (viewedKeys.has(hunk.key) ? [] : [index]));

    return hunkIndexes.length > 0 ? [{ fileId: file.id, hunkIndexes }] : [];
  });
}

function isEveryHunkViewed() {
  return viewedKeysInReview().length > 0 && unviewedScopeFiles().length === 0;
}

/** Hunk has no empty scope, so a fully viewed review is shown whole, dimmed. */
function isHiding() {
  return !showViewed && viewedKeysInReview().length > 0 && !isEveryHunkViewed();
}

function applyScope(controls: ExtensionReviewPresentationControls, generation: string | null) {
  if (!isHiding() || !generation) {
    controls.clearPresentationScope();
    return;
  }

  controls.setPresentationScope({ generation, files: unviewedScopeFiles() });
}

/** The nearest unviewed hunk in the given direction from the selected one, wrapping. */
function findUnviewedTarget(ctx: ExtensionCommandContext, direction: 1 | -1): HunkTarget | null {
  const { file, hunkIndex } = ctx.selection;
  const targets = ctx.selection.files.flatMap((candidate) =>
    (candidate.hunks ?? []).map((hunk) => ({ fileId: candidate.id, hunkIndex: hunk.index })),
  );
  const selected = targets.findIndex(
    (target) => target.fileId === file?.id && target.hunkIndex === hunkIndex,
  );

  return findUnviewedHunk(targets, selected, direction, isViewed);
}

/** Bring the review in line with the viewed state after a command changed it. */
function sync(ctx: ExtensionCommandContext) {
  if (isEveryHunkViewed()) ctx.notify("Every hunk is viewed");

  if (isHiding()) {
    const { file, hunkIndex } = ctx.selection;
    const isSelectionViewed =
      file !== null && hunkIndex !== null && isViewed({ fileId: file.id, hunkIndex });
    const next = isSelectionViewed ? findUnviewedTarget(ctx, 1) : null;

    // Select before scoping: Hunk sends a selection that falls out of scope back to the top.
    if (next) ctx.navigation.selectHunk(next.fileId, next.hunkIndex);
  }

  if (viewedKeysInReview().length > 0) ctx.panes.open(PANE_ID);
  else ctx.panes.close(PANE_ID);

  applyScope(ctx.review, ctx.review.snapshot()?.generation ?? null);
  ctx.highlights.refresh(HIGHLIGHTER_ID);
  publish();
}

function jumpToUnviewed(ctx: ExtensionCommandContext, direction: 1 | -1) {
  const target = findUnviewedTarget(ctx, direction);
  if (!target) {
    ctx.notify(isEveryHunkViewed() ? "Every hunk is viewed" : "No other unviewed hunk");
    return;
  }

  ctx.navigation.selectHunk(target.fileId, target.hunkIndex);
}

/** One progress row; its mount is also what re-applies the scope after a reload dropped it. */
function StatusPane({ actions, keybindings, reviewGeneration, theme }: ExtensionPaneProps) {
  const currentVersion = useSyncExternalStore(subscribe, () => version);

  useEffect(() => {
    applyScope(actions, reviewGeneration);
  }, [actions, currentVersion, reviewGeneration]);

  const viewedCount = viewedKeysInReview().length;
  const hunkCount = [...hunksByFileId.values()].flat().length;
  const key = keybindings.getKeys(`viewed-hunks.${TOGGLE_HIDDEN_COMMAND}`)[0];
  const canToggleHidden = key !== undefined && !isEveryHunkViewed();
  const hint = canToggleHidden ? ` · ${key} to ${isHiding() ? "show" : "hide"} them` : "";

  return (
    <text
      content={` ${viewedCount}/${hunkCount} hunks viewed${hint}`}
      style={{ fg: theme.muted, bg: theme.panel }}
    />
  );
}

export default function (hunk: HunkExtensionAPI) {
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
      const marks = parseHunks(file)
        .filter((parsed) => viewedKeys.has(parsed.key))
        .flatMap((parsed) => parsed.marks);

      return marks.slice(0, MAX_MARKS_PER_FILE);
    },
  });

  hunk.on("changeset_loaded", ({ changeset }, ctx) => {
    // Every toggle is saved at once, so the file also carries what other sessions marked.
    viewedKeys = loadMarks(marksPath, new Date());
    files = changeset.files;
    hunksByFileId = new Map(files.map((file) => [file.id, parseHunks(file)]));

    if (viewedKeysInReview().length > 0) ctx.panes.open(PANE_ID);
    else ctx.panes.close(PANE_ID);

    publish();
  });

  hunk.registerCommand(
    { id: "toggle-hunk", title: "Toggle selected hunk viewed", key: "x" },
    (ctx) => {
      const { file, hunkIndex } = ctx.selection;
      const selected = hunksByFileId.get(file?.id ?? "")?.[hunkIndex ?? -1];
      if (!selected) return;

      const change = toggleViewed([selected.key]);
      sync(ctx);
      saveMarks(marksPath, change, new Date());
    },
  );

  hunk.registerCommand(
    { id: "toggle-file", title: "Toggle selected file viewed", key: "X" },
    (ctx) => {
      const fileHunks = hunksByFileId.get(ctx.selection.file?.id ?? "") ?? [];
      if (fileHunks.length === 0) return;

      const change = toggleViewed(fileHunks.map((parsed) => parsed.key));
      sync(ctx);
      saveMarks(marksPath, change, new Date());
    },
  );

  hunk.registerCommand(
    { id: "next-unviewed", title: "Next unviewed hunk", key: ">" },
    (ctx) => jumpToUnviewed(ctx, 1),
  );

  hunk.registerCommand(
    { id: "previous-unviewed", title: "Previous unviewed hunk", key: "<" },
    (ctx) => jumpToUnviewed(ctx, -1),
  );

  hunk.registerCommand(
    { id: TOGGLE_HIDDEN_COMMAND, title: "Show or hide viewed hunks", key: "H" },
    (ctx) => {
      if (viewedKeysInReview().length === 0) {
        ctx.notify("No viewed hunk yet");
        return;
      }

      // Nothing can be hidden then, so a flip would only surprise once a hunk is unmarked.
      if (isEveryHunkViewed()) {
        ctx.notify("Every hunk is viewed");
        return;
      }

      showViewed = !showViewed;
      sync(ctx);
    },
  );

  hunk.registerCommand({ id: "clear", title: "Clear viewed marks of this review" }, async (ctx) => {
    const keys = viewedKeysInReview();
    if (keys.length === 0) {
      ctx.notify("No viewed hunk yet");
      return;
    }

    const isConfirmed = await ctx.dialogs.confirm({
      title: `Clear ${keys.length} viewed ${keys.length === 1 ? "mark" : "marks"}?`,
      body: "Every hunk of this review becomes unviewed again.",
      confirmLabel: "clear",
    });
    if (!isConfirmed) return;

    const change = toggleViewed(keys);
    sync(ctx);
    saveMarks(marksPath, change, new Date());
  });
}
