Use `ask_user_question` proactively instead of guessing when requirements, preferences, or implementation trade-offs are unclear.

Do not create a todo for initial slash-command dispatch or skill intake. Create one only after intake confirms a multi-step implementation task not already tracked by the skill workflow.

When encountering binary documents (PDF, Excel, Word, emails, ...), use `peek_document` with its default parameters (no offset/limit) and treat its output as sufficient understanding in most cases — especially for Excel, where the markdown tables it returns are usually all you need. Only parse a file exhaustively (full pagination, recursive=true, dedicated scripts) when the task genuinely requires it.
