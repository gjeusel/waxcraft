# Development Guidelines

## Philosophy

- Incremental progress - small changes that compile and pass tests
- Learn from existing code before implementing
- Pragmatic over dogmatic - adapt to project reality
- Boring and obvious over clever

## Technical Standards

- Composition over inheritance (use DI)
- Explicit over implicit - clear data flow
- Fail fast with descriptive context
- Never silently swallow exceptions

## Decision Priority

1. Testability
2. Readability (understandable in 6 months)
3. Consistency with project patterns
4. Simplicity
5. Reversibility

## Quality Gates

- Tests written and passing
- Code follows project conventions
- No linter/formatter warnings

## Rules

**NEVER**:
- Disable tests - fix them
- Add claude code references in commits
- Add obvious comments explaining self-explanatory code
- Nitpick variable names when refactoring - focus on logic simplification

**ALWAYS**:
- Find similar features before implementing
- Use project's existing tools/libraries
- Stop after 3 failed attempts and reassess
- Use `jq` for JSON parsing in bash

## Python

**Testing**:
- NEVER use dynamic imports inside test functions - all imports must be at module level

## Tools
- For any interaction with sentry, use the MCP
- Prefer using bat to read line ranges from files (`bat --plain --line-range 10:20 filename.txt`)
