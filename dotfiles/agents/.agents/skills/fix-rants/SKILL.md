---
name: fix-rants
description: Triage and apply the maintenance proposals logged in ~/.pi/RANT.md, then prune handled entries. Use for "fix the rants", "cleanup the rants", or when asked to process RANT.md.
---

# Fix the rants

`~/.pi/RANT.md` is a human-read log of config/context maintenance proposals, one `## <date> — <title>`
entry each: failure evidence, target file or setting, proposed edit, rationale. This skill is the
sanctioned way to read it back: every entry gets a verified status, the user approves, then the
approved fixes land and handled entries leave the log.

**Hard guardrail: change nothing before explicit confirmation in step 3.** Steps 1–2 are read-only;
this covers target files, `RANT.md` itself, restows, and installs.

## 1. Triage every entry

For each entry, gather evidence before judging:

- **Resolve the real source.** Follow symlinks (`readlink -f`) to the file to edit. Stowed waxcraft
  files are edited in `~/src/waxcraft/dotfiles/...`, never through an unrelated installed copy.
  Note whether the target is git-tracked, untracked, or already dirty.
- **Check whether it is already fixed**: read the target and look for the proposed rule or change.
- **Re-check the failure evidence** against the current environment (files, contexts, commands,
  Makefile targets named in the entry). A rant can be stale or wrong.
- **Judge the proposal on its merits.** When the rule already exists but was ignored, a restated
  rule is a no-op; prefer a mechanical guard (a check, a template, a snippet to copy). When the
  proposal is weak, draft a better fix for the same failure.

Classify each entry as **fixed** (already applied), **to fix**, **obsolete** (evidence no longer
holds or proposal is invalid), or **needs decision** (a user preference the evidence cannot settle).
Triage is done when every entry has a status backed by a concrete observation.

## 2. Draft the edits

For each **to fix** entry, draft the exact change: file path, location, and text. Match the target's
conventions and wording style. For `AGENTS.md`, `CLAUDE.md`, skills, or agent prompts, follow the
`writing-for-agents` skill. When the fix contains a runnable snippet, plan to execute it on
representative input during verification.

## 3. Confirm

Report a compact table: entry, status, evidence, proposed change (file + one-line summary). Then ask
with `ask_user_question`:

- which **to fix** entries to apply (all, a typed subset, or none), and a choice for every
  **needs decision** entry;
- whether to remove the **fixed**, **obsolete**, and to-be-applied entries from `RANT.md`.

Stop here if the user declines everything.

## 4. Apply and verify

Apply only the confirmed edits. Verify with checks proportional to each change: `git diff --check`
in each touched repo, the component check from that repo's `AGENTS.md` when code or config changed,
and execution of any added snippet. Leave every change uncommitted.

Then remove the confirmed entries from `RANT.md`, keeping the header paragraph and any declined or
failed entries untouched.

## 5. Report

List per entry: applied / already fixed / removed as obsolete / kept, with the files changed and the
verification outcomes. Name required follow-ups the user must authorize, such as a restow for a
new stowed file (see `~/src/waxcraft/AGENTS.md`) or an untracked target file.
