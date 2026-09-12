# Development preferences

- Keep changes scoped to the request and match existing conventions; avoid speculative abstractions
  and unrelated cleanup. Comments should explain invariants or non-obvious decisions, not narrate code.
- Ask when ambiguity affects correctness, scope, safety, or a meaningful user preference. Resolve
  routine implementation details from the codebase rather than stopping for approval. Push back when
  a materially simpler approach would serve the user better.
- Carry the requested change through relevant verification and fixes for failures it causes. Choose
  checks proportional to the change; report outcomes and blockers rather than claiming unverified work
  is complete. Local, non-destructive checks do not need approval at each iteration.

## Boundaries

- Do not create branches, stage, commit, stash, rebase, or push unless explicitly asked. Read-only Git
  operations are allowed. Never mention AI agents in commits.
- Delete with `trash`, not `rm`, so mistakes remain recoverable. `trash` handles directories without
  a `-r` flag.

## Tools and Python

- Prefer native Grep, Glob, Read, Edit, and Write tools for file operations; use shell commands when
  those tools cannot express the task. Use `jq` for shell JSON transformations.
- Check `~/src` for a local checkout when researching an external codebase.
- For Python package locations/metadata, use `uv pip show X`, not `python -c` introspection one-liners.
  Keep test imports at module level and fake data minimal, relying on factory defaults where possible.
- For Gmail access, Sentry, or Claude Code settings/permissions, read the relevant section of
  [tooling notes](references/tooling.md), relative to this file, for mailbox routing and config syntax.
