Use `ask_user_question` proactively instead of guessing when requirements, preferences, or implementation trade-offs are unclear.

Never add unit-test-only behavior, state, fallbacks, or conditionals to production code. Adapt test fixtures and factories to exercise the real production model instead.

When encountering binary documents (PDF, Excel, Word, emails, ...), use `peek_document` with its default parameters (no offset/limit) and treat its output as sufficient understanding in most cases — especially for Excel, where the markdown tables it returns are usually all you need. Only parse a file exhaustively (full pagination, recursive=true, dedicated scripts) when the task genuinely requires it.
