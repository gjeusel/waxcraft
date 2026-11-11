---
description: Shorthand for /glab issue, never auto-merging unless asked
argument-hint: "[options, e.g. auto merge, no-subagent, issue title]"
---
Run the glab skill's `/glab issue` workflow on the current task: resolve or create its issue, branch,
and MR, and publish the task's changes.

- Do not enable auto-merge or merge unless my options below explicitly say `auto merge`.
- `no-subagent` means execute the workflow yourself instead of delegating it to a subagent.
- Any other text is the issue reference, title, or extra instructions.

Options: ${@:-none}
