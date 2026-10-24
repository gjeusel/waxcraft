---
name: simplify
description: Simplify recently changed code for clarity and consistency while preserving behavior. Use for "simplify", "clean up", or "refine" requests on a diff, file, or session's changes.
---

# Simplify

Refactor the code in scope so it reads more clearly and follows the repository's conventions, while
every input, output, side effect, and error path stays identical. This is a **behavior-preserving**
refactor: a simplification that would alter what the code does becomes a reported follow-up, not an
edit. Public signatures, exported names, log and error messages, and serialized output count as
behavior.

## 1. Pin scope

Honor an explicit file, range, or ref. Otherwise take the code touched in this session; failing that,
the working-tree changes (`git diff HEAD` plus untracked files). Simplify those hunks and only the
surrounding code they need to stay coherent with; a broader rewrite needs the user's request. Report
"Nothing to simplify." on an empty scope.

Read the applicable guidance before editing: every `AGENTS.md` / `CLAUDE.md` on the path, linter and
formatter config, and neighbouring code. Repository conventions override the generic moves below.

## 2. Simplify every hunk

Look for:

- Deep nesting: flatten with guard clauses and early returns.
- Redundancy: dead branches, duplicated logic, unused variables, parameters, or imports, and
  re-implementations of an existing helper or standard-library function.
- Needless indirection: single-use wrappers, pass-through layers, abstractions with one caller.
- Unclear names: rename to say what the value holds or the function does.
- Scattered logic: consolidate steps that belong together.
- Narrating comments: delete them; keep comments that explain invariants or non-obvious decisions.
- Multi-way conditions written as nested ternaries: use an `if`/`else` chain, `match`/`switch`, or a
  lookup table.

**Explicit beats compact.** Keep a change only when a reader grasps the result faster than the
original: preserve abstractions that organize the code, keep concerns separated, keep it easy to
debug and extend, and prefer a few plain lines over a dense one-liner or clever trick. Fewer lines are
a side effect, never the goal.

## 3. Prove equivalence

Re-read each change against the original and check the edge cases a refactor silently breaks: empty
and null inputs, error paths and exception types, evaluation order and short-circuiting, mutation and
aliasing, laziness, and iteration order. Revert any change you cannot show equivalent.

Then run the project's formatter, linter, type checker, and the tests covering the touched code. The
step is done when every check passes, or each failure is shown to predate your edits.

## 4. Report

List significant changes by file, one line each; skip trivial renames and formatting. Add the
behavior-changing opportunities you left as follow-ups, and the checks run with their results.
