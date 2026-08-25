## Browser behavior

- When opening or interacting with websites, always use the embedded browser panel inside the ChatGPT/Codex app.
- Never launch or control a separate Google Chrome window unless I explicitly request it.
- If the embedded browser cannot perform a required action, explain the limitation before switching to an external browser.

## Deleting Files

- ALWAYS use `trash` (macOS built-in) instead of `rm` to delete files or directories — it moves them to the Finder Trash, so mistakes are recoverable. Example: `trash file.txt dir/`.
- `trash` has no `-r` flag; it handles directories natively.

## Gmail — two mailboxes, two access paths

- `support@renewex.co` → use the **Gmail MCP** tools (`mcp__claude_ai_Gmail__*`)
- `guillaume.jeusel@renewex.co` → use the **gws CLI** (`gws gmail ...`, see gws-gmail skills)
- If a message/thread ID is "not found" with one path, it likely belongs to the other mailbox — try the other tool before concluding the email is inaccessible.
