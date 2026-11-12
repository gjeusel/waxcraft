import assert from "node:assert/strict";
import { test } from "node:test";
import { fade, findUnviewedHunk, parseHunks, windowStart } from "./hunks.ts";

const PATCH = [
  "diff --git a/a.txt b/a.txt",
  "--- a/a.txt",
  "+++ b/a.txt",
  "@@ -2,3 +2,4 @@ heading",
  " keep",
  "-old",
  "+new",
  "+extra",
  " ",
  "@@ -40,2 +41,1 @@",
  "-gone",
  " tail",
  "\\ No newline at end of file",
].join("\n");

test("parseHunks addresses each line on the side it belongs to", () => {
  const [first, second] = parseHunks({ path: "a.txt", patch: PATCH });

  assert.deepEqual(first?.marks, [
    { side: "new", line: 2, range: [0, 4], tone: "dim" },
    { side: "old", line: 3, range: [0, 3], tone: "dim" },
    { side: "new", line: 3, range: [0, 3], tone: "dim" },
    { side: "new", line: 4, range: [0, 5], tone: "dim" },
  ]);
  assert.deepEqual(second?.marks, [
    { side: "old", line: 40, range: [0, 4], tone: "dim" },
    { side: "new", line: 41, range: [0, 4], tone: "dim" },
  ]);
});

test("parseHunks keeps each hunk's own text, header included", () => {
  const [first, second] = parseHunks({ path: "a.txt", patch: PATCH });

  assert.equal(first?.text, "@@ -2,3 +2,4 @@ heading\n keep\n-old\n+new\n+extra\n ");
  assert.equal(second?.text, "@@ -40,2 +41,1 @@\n-gone\n tail");
  assert.deepEqual([first?.line, second?.line], [2, 41]);
});

test("fade moves a colour towards the background, and leaves other notations alone", () => {
  assert.equal(fade("#ffffff", "#000000", 0.5), "#808080");
  assert.equal(fade("#EBCB8B", "#2e3440", 0), "#ebcb8b");
  assert.equal(fade("#ebcb8b", "#2e3440", 1), "#2e3440");
  assert.equal(fade("red", "#000000", 0.5), "red");
  assert.equal(fade("#ffffff", "transparent", 0.5), "#ffffff");
});

test("windowStart keeps the selected row mid-window without running past either end", () => {
  const starts = [0, 4, 5, 12, 19, -1].map((selectedRow) => windowStart(selectedRow, 20, 10));

  assert.deepEqual(starts, [0, 0, 0, 7, 10, 0]);
  assert.equal(windowStart(3, 4, 10), 0);
});

test("parseHunks keys a hunk by path and body, not by position", () => {
  const keysOf = (path: string, patch: string) => parseHunks({ path, patch }).map((h) => h.key);
  const [first, second] = keysOf("a.txt", PATCH);

  const shifted = PATCH.replace("@@ -2,3 +2,4 @@", "@@ -12,3 +12,4 @@");
  const edited = PATCH.replace("+extra", "+extra!");

  assert.notEqual(first, second);
  assert.deepEqual(keysOf("a.txt", shifted), [first, second]);
  assert.notEqual(keysOf("a.txt", edited)[0], first);
  assert.equal(keysOf("a.txt", edited)[1], second);
  assert.notEqual(keysOf("b.txt", PATCH)[0], first);
});

test("parseHunks finds no hunk in a patch without one", () => {
  assert.deepEqual(parseHunks({ path: "logo.png", patch: "Binary files differ" }), []);
});

test("findUnviewedHunk skips viewed hunks, wraps, and never returns its start", () => {
  const viewed = new Set(["b", "c"]);
  const find = (from: number, direction: 1 | -1, hunks = ["a", "b", "c", "d"]) =>
    findUnviewedHunk(hunks, from, direction, (hunk) => viewed.has(hunk));

  assert.equal(find(0, 1), "d");
  assert.equal(find(3, 1), "a");
  assert.equal(find(0, -1), "d");
  assert.equal(find(2, -1), "a");
  assert.equal(find(-1, 1), "a");
  assert.equal(find(-1, -1), "d");
  assert.equal(find(0, 1, ["a", "b", "c"]), null);
  assert.equal(find(-1, 1, []), null);
});
