# Tooling notes

## Gmail: route by mailbox

- `support@renewex.co`: Gmail MCP (`mcp__claude_ai_Gmail__*`).
- `guillaume.jeusel@renewex.co`: `gws gmail ...`; use the applicable gws-gmail skill.
- If the mailbox is unknown and a message/thread ID is not found, try the other access path before
  concluding the message is inaccessible. A failed lookup does not authorize sending from another account.

## Sentry

Use the Sentry MCP for Sentry interactions.

## Claude Code settings and permissions

- `~/.claude/settings.json` is strict JSON, not JSONC; comments are invalid.
- Permission syntax is `Bash(cmd *)` (space-asterisk), not the deprecated `Bash(cmd:*)`.
- Compound commands such as `cd /path && git log` also need `Bash(cd *)` in the allow list.
