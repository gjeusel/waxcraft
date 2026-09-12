# Global Development Guidelines

## Working Style

- Use `ask_user_question` when ambiguity affects correctness, scope, safety, or a meaningful user preference. Resolve routine implementation details from the codebase without stopping for approval.
- Prefer the simplest implementation that fully satisfies the request.
- Keep changes surgical: avoid unrelated refactoring, formatting, or cleanup, and match the existing codebase's conventions.
- Use comments to explain invariants or non-obvious decisions, not to narrate code. Preserve existing comments while they remain relevant.

## Code Layout

- Prefer "aerated" code: use blank lines between logical steps, after guard clauses, before final returns, and between substantial control-flow branches, while keeping tightly related statements together.
- Define functions top to bottom in dependency order: a helper must appear above the function that calls it, so a file reads without forward references.
- Avoid a proliferation of tiny helpers: inline logic that is used only once unless it names a genuinely distinct step.
- Make complex boolean logic readable by naming meaningful subconditions with descriptive intermediate variables; preserve short-circuit evaluation where it affects behavior or cost.
- Wrap code comments and docstrings near the 100-character maximum (including indentation), not prematurely at 72 or 80 characters; keep sentences and expressions together when they fit to improve readability and comprehension.

## Completion

- Carry the requested change through relevant verification and fixes for failures it causes. Choose checks proportional to the change; local, non-destructive checks do not need approval at each iteration.
- Report actual verification outcomes and any blockers. Do not stop at a first implementation when requested validation or fixes remain, or expand into unrelated failures.
- Never add unit-test-only behavior, state, fallbacks, or conditionals to production code. Adapt test fixtures and factories to exercise the real production model instead.

## Git

- Do not create branches, stage, commit, stash, rebase, or push unless explicitly asked. Read-only Git operations are allowed.
- Never mention AI agents in commits.

## Document Handling

For PDF, Office, or email files, start with `peek_document` defaults. Follow up with targeted pages,
sheets, or attachments when needed to answer the task; do not parse the entire document by default.
