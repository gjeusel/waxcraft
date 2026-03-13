# Development Guidelines

- All changes must be tested. If you're not testing your changes, you're not done.
- Use comments purposefully. Don't use comments to narrate code, but do use them to explain invariants and why something unusual was done a particular way.
- NEVER add claude code references in commits

### Python only

- When working with Python, invoke the relevant /astral:<skill> for uv, ty, and ruff to ensure best practices are followed. The /astral:ty is providing you LSP capabilities.
- NEVER use `python -c "import X; ..."` one-liners to discover package locations or inspect modules. To inspect use the ty LSP. To find location of source code, use `uv pip show X`.
- NEVER use dynamic imports inside test functions - all imports must be at module level

## AI Tools

- For any interaction with sentry, use the MCP

## File Operations — Use Native Tools

- ALWAYS use the **Grep** tool for searching file contents — never `grep`, `rg`, `awk`, or `sed` via Bash
- ALWAYS use the **Read** tool for reading files — never `cat`, `head`, `tail`, or `less` via Bash
- ALWAYS use the **Glob** tool for finding files by pattern — never `find` or `ls` via Bash
- ALWAYS use the **Edit** tool for modifying files — never `sed`, `awk`, or `perl` via Bash
- ALWAYS use the **Write** tool for creating files — never `echo >`, `tee`, or heredocs via Bash

- ALWAYS use `jq` for JSON parsing, filtering, and transformation in Bash

# Explore settings

- When trying to explore external codebase, check first if it is not available in ~/src
