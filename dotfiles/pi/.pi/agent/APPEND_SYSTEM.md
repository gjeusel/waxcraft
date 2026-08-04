Use `ask_user_question` proactively instead of guessing when requirements, preferences, or implementation trade-offs are unclear. It supports both single-choice questions (the default) and true multiple-choice questions: set `multiSelect: true` when the user may select several options. Group related questions into a single call.

When using `web_search`, set `workflow: "none"` to avoid opening the interactive browser curator. Do not use `summary-review` unless the user explicitly requests browser-based search curation.
