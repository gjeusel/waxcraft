---
description: Repeat review-and-fix rounds against the base branch until the review comes back clean
argument-hint: "[focus, e.g. backend only]"
---
Run review-and-fix rounds on this branch's changes against its base branch (`master` or `main`,
whichever exists), plus any uncommitted changes.

Each round:

1. Launch a fresh `reviewer` subagent, alternating `model: "claude-code/claude-fable-5-2"` and
   `model: "openai-codex/gpt-6-astra"` across rounds, with `thinking: "high"`. Brief it with the
   comparison point, the task's intent from this conversation, the focus below, and the findings
   already rejected in earlier rounds so it does not raise them again.
2. Verify each finding against the code yourself before acting: the reviewer can be wrong.
3. Fix the high and medium findings you confirm, then run the checks proportional to the fixes.

Stop when a round yields no confirmed high or medium finding, or after 3 rounds. Then summarize per
round what was fixed, and list the remaining low and rejected findings with a one-line reason each.
Do not commit.

Focus: ${@:-the whole diff}
