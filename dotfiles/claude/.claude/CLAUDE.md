# Development Guidelines

- All changes must be tested. If you're not testing your changes, you're not done.
- Use comments purposefully. Don't use comments to narrate code, but do use them to explain invariants and why something unusual was done a particular way.
- NEVER add AI agent references in commits
- NEVER TAKE THE INITIATIVE TO PUSH YOURSELF ON THE MASTER/MAIN BRANCH. This is allowed only when the user explicitly asks for it.
- NEVER take git initiatives on your own — no creating branches, staging, committing, stashing, rebasing, or pushing unless I explicitly ask for it. Read-only git (status, diff, log) is fine.

### Python only

- NEVER use `python -c "import X; ..."` one-liners to discover package locations or inspect modules. Use `uv pip show X` instead.
- NEVER use dynamic imports inside test functions - all imports must be at module level
- Keep unit-test fake data minimal: specify only what affects the assertion or code path under test, and rely on factory defaults for the rest.

## File Operations — Use Native Tools

- ALWAYS use the **Grep** tool for searching file contents — never `grep`, `rg`, `awk`, or `sed` via shell
- ALWAYS use the **Read** tool for reading files — never `cat`, `head`, `tail`, or `less` via shell
- ALWAYS use the **Glob** tool for finding files by pattern — never `find` or `ls` via shell
- ALWAYS use the **Edit** tool for modifying files — never `sed`, `awk`, or `perl` via shell
- ALWAYS use the **Write** tool for creating files — never `echo >`, `tee`, or heredocs via shell

## AI Tools

- For any interaction with sentry, use the MCP
- ALWAYS use `jq` for JSON parsing, filtering, and transformation in shell commands

### Claude Code config files

- `~/.claude/settings.json` is **strict JSON** — no JSONC, no comments.
- Permission syntax is `Bash(cmd *)` (space-asterisk); `Bash(cmd:*)` (colon-asterisk) is the deprecated form.
- Compound commands (`cd /path && git log`) need `Bash(cd *)` in the allow list too.

### Gmail — two mailboxes, two access paths

- `support@renewex.co` → use the **Gmail MCP** tools (`mcp__claude_ai_Gmail__*`)
- `guillaume.jeusel@renewex.co` → use the **gws CLI** (`gws gmail ...`, see gws-gmail skills)
- If a message/thread ID is "not found" with one path, it likely belongs to the other mailbox — try the other tool before concluding the email is inaccessible.

# Explore settings

- When trying to explore external codebase, check first if it is not available in ~/src

# RULES

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
