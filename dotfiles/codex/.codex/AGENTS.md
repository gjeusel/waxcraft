## Browser behavior

- When opening or interacting with websites, always use the embedded browser panel inside the ChatGPT/Codex app.
- Never launch or control a separate Google Chrome window unless I explicitly request it.
- If the embedded browser cannot perform a required action, explain the limitation before switching to an external browser.

## Deleting Files

- ALWAYS use `trash` (macOS built-in) instead of `rm` to delete files or directories — it moves them to the Finder Trash, so mistakes are recoverable. Example: `trash file.txt dir/`.
- `trash` has no `-r` flag; it handles directories natively.

## Email links

- For Mimestream links shaped `https://links.mimestream.com/g/<account>/m/<message-id>`, extract the account and Gmail message ID and use the Gmail plugin first. Use a browser or mail app only when the plugin cannot perform the required action, and explain that limitation.



# Renewex organization instructions

These instructions apply to every Claude Code session of the organization, in any repository. A
repository's own `AGENTS.md` or `CLAUDE.md` adds its specifics and wins on a conflict.

## Coding

### Principles

- Prefer the simplest implementation that fully satisfies the request.
- Keep changes surgical: touch what the request needs, and match the conventions of the code
  around it. Leave unrelated refactoring, formatting, and cleanup for a change of their own.
- Homogenize the vocabulary: one concept, one name; one name, one concept. Reuse the codebase's
  established term before coining a new one.
- Inline logic that is used only once, unless a helper names a genuinely distinct step.

### Layout

- A file reads top to bottom: define helpers, fixtures, and private methods above the functions,
  methods, and tests that call them, in modules, classes, and test files alike.
- Write aerated code: blank lines between logical steps, after guard clauses, before a final
  return, and between substantial control-flow branches; tightly related statements stay together.
- Name the meaningful subconditions of a complex boolean expression with intermediate variables,
  keeping short-circuit evaluation where it affects behavior or cost.

### Comments

- A comment explains an invariant or a non-obvious decision; clear names and code explain the rest.
- Comment sparingly: state a reason once, in one or two lines, on the definition that owns it.
- Keep existing comments while the code they explain remains.
- Wrap comments and docstrings near 100 characters, indentation included, keeping a sentence or an
  expression together when it fits.

### Tests

- Production code holds only production behavior: exercise the real model through fixtures and
  factories, adapting them instead of adding a test-only branch, state, or fallback.
