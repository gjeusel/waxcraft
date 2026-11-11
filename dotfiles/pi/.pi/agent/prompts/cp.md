---
description: Commit and push the current task's changes
argument-hint: "[notes, e.g. on master, all, don't apply in k8s]"
---
Commit and push the changes of the current task. This request authorizes the staging, commit, and
push it needs; do not ask for confirmation when the scope is clear.

- On a GitLab remote, follow the glab skill's `/glab push` workflow. Elsewhere, commit on the current
  branch and push it to its upstream, setting one if missing.
- Scope: the changes this conversation made or discussed. Include every one of them, even when a local
  check or environment gap gets in the way; report that gap rather than silently skipping files.
  Leave unrelated changes uncommitted and list them.
- Write the commit message from the diff, following the repository's recent `git log` conventions.
- Never amend, rebase, force-push, or merge unless my notes ask for it.
- Report the commit SHA, branch, and any leftovers in a few lines.

${@:-}
