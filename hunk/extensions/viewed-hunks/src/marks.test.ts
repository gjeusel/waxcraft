import assert from "node:assert/strict";
import { mkdtempSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { MARK_TTL_MS, loadMarks, resolveMarksPath, saveMarks } from "./marks.ts";

const NOW = new Date("2026-11-11T12:00:00Z");

function marksPath() {
  return join(mkdtempSync(join(tmpdir(), "viewed-hunks-")), "state", "viewed-hunks.json");
}

/** The marks on disk, as plain sorted values. */
function load(path: string, now = NOW) {
  const marks = loadMarks(path, now);

  return {
    viewed: [...marks.viewed].sort(),
    kept: [...marks.kept].sort(),
    noise: Object.fromEntries(marks.noise),
  };
}

test("resolveMarksPath follows XDG_STATE_HOME only when it is absolute", () => {
  const resolve = (env: NodeJS.ProcessEnv) => resolveMarksPath(env, "/home/me");
  const fallback = "/home/me/.local/state/hunk/viewed-hunks.json";

  assert.equal(resolve({ XDG_STATE_HOME: "/state" }), "/state/hunk/viewed-hunks.json");
  assert.equal(resolve({ XDG_STATE_HOME: "state" }), fallback);
  assert.equal(resolve({}), fallback);
});

test("saved marks are loaded back, and removed ones are not", () => {
  const path = marksPath();

  saveMarks(path, { viewed: { added: ["a", "b"] }, kept: { added: ["k"] } }, NOW);
  const verdicts = new Map([
    ["n", { noise: 0.97, structure: 0.8, interface: 0.1 }],
    ["m", { noise: 0.1 }],
  ]);
  saveMarks(path, { noise: { added: verdicts } }, NOW);
  saveMarks(path, { viewed: { added: ["c"], removed: ["a"] }, noise: { removed: ["m"] } }, NOW);

  const noise = { n: { noise: 0.97, structure: 0.8, interface: 0.1 } };
  assert.deepEqual(load(path), { viewed: ["b", "c"], kept: ["k"], noise });
  assert.deepEqual(readdirSync(join(path, "..")), ["viewed-hunks.json"]);
});

test("a mark expires once it is older than the TTL", () => {
  const path = marksPath();
  const verdict = { noise: 1, structure: undefined, interface: undefined };
  saveMarks(path, { viewed: { added: ["old"] }, noise: { added: new Map([["n", verdict]]) } }, NOW);

  const beforeExpiry = new Date(NOW.getTime() + MARK_TTL_MS);
  const afterExpiry = new Date(NOW.getTime() + MARK_TTL_MS + 1);
  assert.deepEqual(load(path, beforeExpiry), { viewed: ["old"], kept: [], noise: { n: verdict } });
  assert.deepEqual(load(path, afterExpiry), { viewed: [], kept: [], noise: {} });

  saveMarks(path, { viewed: { added: ["new"] } }, afterExpiry);
  assert.deepEqual(load(path, afterExpiry), { viewed: ["new"], kept: [], noise: {} });
});

test("a file holding only viewed marks is still read", () => {
  const path = marksPath();
  saveMarks(path, {}, NOW);
  writeFileSync(path, JSON.stringify({ version: 1, hunks: { a: NOW.toISOString() } }));

  assert.deepEqual(load(path), { viewed: ["a"], kept: [], noise: {} });
});

test("a missing or unusable file holds no mark and is replaced on save", () => {
  const path = marksPath();
  const empty = { viewed: [], kept: [], noise: {} };
  assert.deepEqual(load(path), empty);

  saveMarks(path, { viewed: { added: ["a"] } }, NOW);
  const unusable = [
    "not json",
    "null",
    '{"hunks": 3, "noise": "x"}',
    '{"hunks": {"a": "not a date"}}',
    '{"noise": {"a": null, "b": {"at": "2026-11-11T12:00:00Z"}}}',
  ];
  for (const content of unusable) {
    writeFileSync(path, content);
    assert.deepEqual(load(path), empty, content);
  }

  saveMarks(path, { viewed: { added: ["b"] } }, NOW);
  assert.deepEqual(load(path), { ...empty, viewed: ["b"] });
});
