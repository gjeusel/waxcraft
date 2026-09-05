# Global Development Guidelines

## Working Style

- Use `ask_user_question` proactively instead of guessing when requirements, preferences, or implementation trade-offs are unclear.
- Prefer the simplest implementation that fully satisfies the request.
- Keep changes surgical: avoid unrelated refactoring, formatting, or cleanup, and match the existing codebase's conventions.
- Use comments to explain invariants or non-obvious decisions, not to narrate code. Preserve existing comments while they remain relevant.

## Code Layout

- Define functions top to bottom in dependency order: a helper must appear above the function that calls it, so a file reads without forward references.
- Avoid a proliferation of tiny helpers: inline logic that is used only once unless it names a genuinely distinct step.
- Wrap code comments and docstrings near the 100-character maximum (including indentation), not prematurely at 72 or 80 characters; keep sentences and expressions together when they fit to improve readability and comprehension.

## Testing

- Test all code changes using the project's appropriate checks.
- Never add unit-test-only behavior, state, fallbacks, or conditionals to production code. Adapt test fixtures and factories to exercise the real production model instead.

## Git

- Do not create branches, stage, commit, stash, rebase, or push unless explicitly asked. Read-only Git operations are allowed.
- Never mention AI agents in commits.

## Document Handling

When encountering binary documents such as PDF, Word, Excel, or email files:

- Use `peek_document` with its default parameters first.
- Treat its initial output as sufficient in most cases, especially for spreadsheets.
- Parse exhaustively—using pagination, recursive attachment extraction, or dedicated scripts—only when the task genuinely requires it.
