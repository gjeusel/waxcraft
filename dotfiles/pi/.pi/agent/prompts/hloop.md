---
description: Address my review notes in the live Hunk session, one reply per note
argument-hint: "[file or extra instructions]"
---
Address the review notes I left with `c` in the live Hunk session for this repository. Use the
hunk-review skill for the `hunk session` commands; never launch `hunk diff` or `hunk show` yourself.

1. Run `hunk session list`. Select the session whose repo is the current repository; if several
   match, use its session id. If none exists, stop and ask me to open Hunk.
2. Run `hunk session comment list --repo . --type all --json`. My notes have `source: "user"`.
   Skip a note whose most recent reply is yours, unless I replied to it again afterwards.
3. Take my open notes in file then line order. For each one:
   - Run `hunk session navigate --repo . --comment <noteId>` so my view follows you.
   - Read the surrounding code before acting. Implement a requested change, answer a question, or
     reject a request you disagree with instead of editing.
   - Reply with `hunk session comment add --repo . --reply-to <noteId> --summary "..."`: one terse
     sentence of at most 10 words, without `--rationale`, usually just `done` or `rejected: <reason>`.
     Pass `--focus` on your first reply so agent notes become visible.
   - Anything needing more words stays out of Hunk: explain longer answers or reasoning in this
     conversation, and ask clarifying questions or confirm a rejection with `ask_user_question`,
     batching the questions from every note into one call rather than one per note.
4. Never remove or clear my notes: I decide when a thread is resolved.
5. Make one pass over the notes that exist now, then stop; I rerun `/hloop` after adding more.
6. Run the checks proportional to the changes you made, then summarize the notes as done,
   answered, or rejected, with the files you changed.

${@:-Address every open note.}
