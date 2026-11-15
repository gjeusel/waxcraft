---
name: rethink
description: Reopen the design of a working codebase (architecture, stack, custom code versus existing libraries) to turn a POC into a mature project, features preserved. Use for "rethink", or when asked to challenge a project's tech choices or architecture.
---

A project grown feature by feature holds a design nobody chose. Rethink reopens it: knowing every
feature at once, would this design be chosen again today? The features are the **core value** and
survive untouched; how they are built is entirely open.

A **decision** is a choice that would deserve an ADR and can be stated without quoting code: a
dependency, a hand-rolled mechanism, a module boundary, where state lives, how data flows. Code
that merely repeats, runs long, or is badly named belongs to `simplify`, `vocabularize`, and
`improve`; so do tests, security, and CI.

## 1. Read

Read the whole project, or the part the prompt names. Deduce the features it delivers, then list
every decision behind them with its reason: a commit, a comment, an ADR, or "unknown".

## 2. Redesign

Design the project from a blank page for the full feature list, before judging the one that
grew. Then challenge each decision against that design and against the outside world:

- **reshape**: the blank-page architecture differs: other boundaries, another data flow, another
  home for state. Look at how the reference projects of the domain structure the same problem.
- **replace**: a library or tool retires a custom mechanism, or fits better than a current
  dependency. Search online for every one of them, and trust the registry page, the repository,
  and the changelog over memory: version, last release, maintenance, license, features covered.
- **unify**: two libraries, mechanisms, or conventions compete for one job; one wins.
- **drop**: no feature needs it: speculative abstraction, configurability nobody configures.

Rate each change's **impact**: `high` crosses module boundaries or changes how data flows,
`medium` rewrites one module, `low` stays local.

## 3. Propose

Answer with the table and nothing around it: the decisions to change, sorted by verdict in the
order above, then by impact, highest first. Each cell is a few words.

```markdown
| #   | Verdict | Impact | Decision      | Now                      | Proposal                  |
| --- | ------- | ------ | ------------- | ------------------------ | ------------------------- |
| 1   | reshape | high   | Response size | 30 call sites, 3 helpers | enforce once, `call_tool` |
| 2   | replace | low    | RFC 3339      | hand-rolled, `time.rs`   | `chrono`, already a dep   |
```
