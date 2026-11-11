---
description: Review the branch against its base with a reviewer subagent, then fix what matters
argument-hint: "[focus, e.g. backend only, revenue_logic.py]"
---
Review this branch's changes against its base branch (`master` or `main`, whichever exists), plus any
uncommitted changes, then fix the findings that matter.

1. Launch one `reviewer` subagent with `model: "claude-code/claude-fable-5-2"` and `thinking: "high"`.
   Brief it with the comparison point, the task's intent from this conversation, and the focus below.
2. Verify each finding against the code yourself before acting: the reviewer can be wrong.
3. Fix the high and medium findings you confirm. List low findings and the ones you reject, each with
   a one-line reason, without fixing them.
4. Run the checks proportional to the fixes.
5. Summarize: fixed, skipped, rejected. Do not commit.

Focus: ${@:-the whole diff}
