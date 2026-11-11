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

test("resolveMarksPath follows XDG_STATE_HOME only when it is absolute", () => {
  const resolve = (env: NodeJS.ProcessEnv) => resolveMarksPath(env, "/home/me");
  const fallback = "/home/me/.local/state/hunk/viewed-hunks.json";

  assert.equal(resolve({ XDG_STATE_HOME: "/state" }), "/state/hunk/viewed-hunks.json");
  assert.equal(resolve({ XDG_STATE_HOME: "state" }), fallback);
  assert.equal(resolve({}), fallback);
});

test("saved marks are loaded back, and removed ones are not", () => {
  const path = marksPath();

  saveMarks(path, { added: ["a", "b"], removed: [] }, NOW);
  saveMarks(path, { added: ["c"], removed: ["a"] }, NOW);

  assert.deepEqual([...loadMarks(path, NOW)].sort(), ["b", "c"]);
  assert.deepEqual(readdirSync(join(path, "..")), ["viewed-hunks.json"]);
});

test("a mark expires once it is older than the TTL", () => {
  const path = marksPath();
  saveMarks(path, { added: ["old"], removed: [] }, NOW);

  const beforeExpiry = new Date(NOW.getTime() + MARK_TTL_MS);
  const afterExpiry = new Date(NOW.getTime() + MARK_TTL_MS + 1);
  assert.deepEqual([...loadMarks(path, beforeExpiry)], ["old"]);
  assert.deepEqual([...loadMarks(path, afterExpiry)], []);

  saveMarks(path, { added: ["new"], removed: [] }, afterExpiry);
  assert.deepEqual([...loadMarks(path, afterExpiry)], ["new"]);
});

test("a missing or unusable file holds no mark and is replaced on save", () => {
  const path = marksPath();
  assert.deepEqual([...loadMarks(path, NOW)], []);

  saveMarks(path, { added: ["a"], removed: [] }, NOW);
  for (const content of ["not json", "null", '{"hunks": 3}', '{"hunks": {"a": "not a date"}}']) {
    writeFileSync(path, content);
    assert.deepEqual([...loadMarks(path, NOW)], [], content);
  }

  saveMarks(path, { added: ["b"], removed: [] }, NOW);
  assert.deepEqual([...loadMarks(path, NOW)], ["b"]);
});
