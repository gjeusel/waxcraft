---
name: code-review
description: "Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes: Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?). Runs both as separate review passes and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to \"review since X\"."
---

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?

Run the two axes as separate passes in the same session. Keep their evidence and conclusions distinct, then report them side by side.

A missing specification never blocks the review: the Standards pass always runs, and the Spec pass runs only when a specification is found.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail before either review pass begins.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. A path or issue the user passed as an argument.
2. Issue references in the commit messages or branch name (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched via the workflow in `docs/agents/issue-tracker.md` when it exists, otherwise directly with the forge CLI (`glab issue view`, `glab mr view`, `gh issue view`, `gh pr view`).
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, do not stop to ask: proceed without a spec, skip the **Spec** pass, and list the sources checked in the report. Ask only when the user said a spec exists but it cannot be located or fetched.

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec (or, without one, the change's evident purpose) doesn't have. → delete it; inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Run both review passes

Do not delegate either pass to a sub-agent. Perform them yourself in this order, keeping their working notes and findings separate.

**Standards pass:**

- Review the full diff and commit list.
- Use the standards-source files found in step 3 and the complete smell baseline above.
- Report, at its `path:line`: (a) every place the diff violates a documented standard, citing the standard file and rule; and (b) any baseline smell, naming it.
- Distinguish hard violations from judgement calls: documented-standard breaches can be hard (`P0`–`P2`), but baseline smells are always `P3` judgement calls, and a documented repository standard overrides the baseline.
- Skip anything tooling already enforces.

**Spec pass:**

- Review the same diff and commit list against the path or fetched contents of the specification.
- Report: (a) requirements that are missing or partial; (b) behavior that was not requested (scope creep); and (c) requirements that appear implemented but whose implementation is wrong.
- Quote the relevant specification line for each finding.

If no specification was found, skip the Spec pass and, under `## Spec`, report "Skipped: no spec found" followed by the sources checked.

### 5. Present the result

Write the report in GitLab-flavoured Markdown, so it pastes unchanged into an MR note:

```markdown
## Confidence Score: <1-5>/5

<Verdict, 1-2 sentences: whether the change is ready to merge, naming the worst finding of each axis.>

## Standards

1. ![P2](https://img.shields.io/badge/P2-daff01?style=flat-square) **<Consequence title>** · `<path>:<line>`

   <Finding body.>

   **Context used:** `<standards file>`: "<quoted rule>"

## Spec

1. ![P1](https://img.shields.io/badge/P1-ff9c7f?style=flat-square) **<Consequence title>** · `<path>:<line>`

   <Finding body.>

   **Spec:** "<quoted spec line>"

<details><summary>Summary</summary>

<One sentence: what the change does.>
- <Notable change, coverage added, or caveat.>

</details>

<sub>Reviewed `<fixed-point>...HEAD` (<N> commits) · Last commit: `<short-sha>` <subject> · Spec: <source, or "none found"></sub>
```

Priorities, each rendered as a coloured badge `![Pn](https://img.shields.io/badge/Pn-<colour>?style=flat-square)` (Greptile's palette):

- `P0` (`ff6d6d`): breaks production: data loss or corruption, a security hole, a crash on a common path.
- `P1` (`ff9c7f`): a real bug, or a spec requirement missing or implemented wrong. Fix before merge.
- `P2` (`daff01`): a documented-standard violation, a partial requirement, scope creep, or a bug on a rare path.
- `P3` (`c4c4c4`): a judgement call: every baseline smell, and minor nits.

Findings:

- Number findings within each axis, ordered by priority. Keep the axes in separate sections: merging or reranking across them defeats the separation (see _Why two axes_).
- Title each finding with the consequence, what goes wrong for users or data, in a few words: "Manual invoices remain excluded", "Tariff column left blank". For a smell, title it "Possible <smell>: <what it costs>".
- Write the body as one impact paragraph: the triggering condition, the mechanism in the code, the consequence, and the evidence it is real (for example, a test that sets up state the production path never produces). Add a one-sentence fix only when the fix is non-obvious.
- Score confidence from the worst finding across both axes: `5` nothing above `P3`, `4` at worst `P2`, `3` one `P1`, `2` several `P1`, `1` any `P0`. The score is a merge verdict, not a ranking: the verdict still names each axis's worst finding separately.
- Write "No findings." under a clean axis, so a clean pass is distinguishable from a skipped one.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
