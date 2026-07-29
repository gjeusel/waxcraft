# Claude Code — cheatsheet

Power-user notes. Keybindings and command lists below were extracted from the shipped binary
(`2.1.220`), not from the docs, so they reflect actual defaults.

Regenerate after an upgrade:

```sh
strings -n 4 ~/.local/share/claude/versions/$(claude --version | cut -d' ' -f1) > /tmp/cc.strings
# then grep for  jar=[{context:"Global"   — that's the default keybinding table
```

## Model & effort

`/model` opens a picker. The non-obvious part is that **`Enter` saves your pick as the default for
new sessions**, which is usually not what you want mid-task:

| Key           | Action                                                       |
| ------------- | ------------------------------------------------------------ |
| `Enter`       | Set as default (persists to `~/.claude/settings.json`)       |
| `s`           | **Use this session only** (`modelPicker:thisSessionOnly`)     |
| `←` / `→`     | Decrease / increase effort for the selected model             |
| `Esc`         | Cancel                                                        |

Confirmation text tells you which happened: *"and saved as your default for new sessions"* vs
*"for this session only"*. While pinned to a session-only model you'll see *"Currently using X for
this session only. Selecting a model will undo this."*

`/effort <low|medium|high|xhigh|max|ultracode|auto>` — same persist-vs-session distinction, same
wording in the confirmation. `ultracode` is xhigh + dynamic workflow orchestration and is **always
session-only**. `CLAUDE_CODE_EFFORT_LEVEL` pins effort for the session; run `/effort` interactively
to release the pin.

`/fast` toggles fast mode (Opus with faster output — not a smaller model). Switching to a
non-Opus model turns it off. Also session-only unless persisted.

## Keybindings

`/keybindings` opens `~/.claude/keybindings.json` to remap any of these. Bindings are
context-scoped; the same chord means different things in the transcript vs the prompt.

### Global

| Chord                     | Action                    |
| ------------------------- | ------------------------- |
| `ctrl+c`                  | Interrupt                 |
| `ctrl+d`                  | Exit                      |
| `ctrl+t`                  | Toggle todos              |
| `ctrl+o`                  | Toggle transcript         |
| `ctrl+r`                  | History search            |
| `ctrl+]`                  | Open artifact             |
| `ctrl+shift+b`            | Toggle brief mode         |
| `ctrl+↑`/`↓`, `meta+↑`/`↓` | Diff file list up / down |

### Chat (the prompt box)

| Chord                      | Action                                        |
| -------------------------- | --------------------------------------------- |
| `shift+tab`                | Cycle permission mode (manual → acceptEdits → plan) |
| `meta+p` (alt/opt+p)       | Model picker                                  |
| `meta+t`                   | **Toggle thinking**                           |
| `meta+o`                   | Toggle fast mode                              |
| `meta+w`                   | Toggle workflow keyword (ultracode)           |
| `ctrl+j`                   | Newline (not submit)                          |
| `ctrl+g` / `ctrl+x ctrl+e` | Edit prompt in `$EDITOR`                      |
| `ctrl+s`                   | **Stash** the current prompt draft            |
| `ctrl+_` / `ctrl+-`        | Undo in the input                             |
| `ctrl+l`                   | Clear input (`cmd+k` clears screen)           |
| `ctrl+x ctrl+k`            | Kill running agents                           |
| `ctrl+v` (`alt+v` on Win/WSL) | Paste image from clipboard                 |
| `esc`                      | Cancel current turn                           |
| `↑` / `↓`                  | Prompt history                                |
| `space` (held)             | Push-to-talk voice                            |

Prefixes: `!` runs a shell command in-session (output lands in the conversation), `#` writes to
memory, `@` mentions a file, `/` a skill or command.

### Transcript view (`ctrl+o`)

Less-style: `j`/`k` lines, `ctrl+u`/`ctrl+d` half page, `ctrl+b`/`ctrl+f`/`space`/`b` full page,
`g`/`shift+g` top/bottom, `ctrl+e` toggle show-all, `q`/`esc` exit.

### Other contexts

- **History search** (`ctrl+r`): `ctrl+r` next match, `ctrl+s` cycle scope, `tab`/`esc` accept,
  `enter` execute.
- **Task**: `ctrl+b` (or `ctrl+x ctrl+b`) backgrounds a running task. Under tmux press `ctrl+b`
  twice.
- **Confirmation dialogs**: `y`/`n`, `ctrl+e` toggle explanation, `shift+tab` cycle mode.
- **Diff dialog**: `←`/`→` change source, `j`/`k` files, `enter` details.
- **Theme picker**: `ctrl+t` toggle syntax highlighting, `ctrl+e` edit custom theme.
- **Plugin browser**: `space` toggle, `i` install, `f` favorite.
- **Scroll/selection**: `shift+arrows` extend selection, `cmd+c` / `ctrl+shift+c` copy.

## Lesser-known commands

Context and cost:

- `/context` — context usage as a colored grid
- `/compact [instructions]` — summarize now, optionally with a focus
- `/autocompact` — set how full context gets before auto-summarizing
- `/skill-doctor` — **which loaded skills are unused and costing context**
- `/clear` — new session, empty context; the old one stays on disk and is resumable

Conversation topology:

- `/branch [name]` — branch the conversation at this point
- `/fork [prompt]` — background agent inheriting the full conversation
- `/subtask` — send a subagent off with your full context, result comes back here
- `/btw <question>` — side question without polluting the main history
- `/rewind`, `esc esc` — roll back code + conversation (file snapshots, separate from git)
- `/diff` — uncommitted changes and per-turn diffs
- `/recap`, `/copy [N]`, `/export`

Review and planning:

- `/plan` — enable plan mode or view the current session plan
- `/code-review`, `/security-review` — local diff review
- `/ultraplan`, `/ultrareview` — cloud-hosted multi-agent plan/review of the branch
  (also `claude ultrareview` from the shell)
- `/goal <condition>` — a goal Claude checks before stopping
- `/advisor` — let Claude consult a stronger model at key moments

Session and env:

- `/cd`, `/add-dir` — move or widen the working directory
- `/teleport` — resume a session from claude.ai; `/stop` ends a background session
- `/loops`, `/daemon` — recurring work and background services
- `/insights`, `/team-onboarding` — reports over your own session history
- `/alias name=value` — command aliases
- `/reload-plugins`, `/reload-skills` — pick up on-disk changes mid-session
- `/powerup` — interactive feature lessons
- `/status`, `/doctor`, `/keybindings`, `/memory`, `/hooks`, `/mcp`, `/config`

## CLI flags worth remembering

| Flag                          | Notes                                                              |
| ----------------------------- | ------------------------------------------------------------------ |
| `-p, --print`                 | Non-interactive. Skips the trust dialog; invalid settings silently ignored |
| `--output-format`             | `text` \| `json` \| `stream-json` (print only)                     |
| `--json-schema <schema>`      | Validate structured output                                          |
| `-c` / `-r [id]`              | Continue most recent / resume by id or picker                       |
| `--fork-session`              | Resume into a *new* session id instead of reusing                   |
| `--from-pr [n]`               | Resume the session linked to a PR                                   |
| `-w, --worktree [name]`       | Fresh git worktree for the session (`--tmux` to pane it)            |
| `--bg`                        | Start as background agent (`claude agents` to manage)               |
| `-n, --name`                  | Display name in prompt box, `/resume` picker, terminal title        |
| `--permission-mode`           | `manual`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions` |
| `--effort`, `--model`         | Session-scoped, not persisted                                       |
| `--fallback-model a,b`        | On overload, try each in order (print only)                         |
| `--max-budget-usd`            | Spend cap (print only)                                              |
| `--max-turns`                 | Cap agentic turns                                                   |
| `--safe-mode`                 | Disable *all* customizations to debug a broken config               |
| `--bare`                      | Minimal: no hooks/LSP/plugins/auto-memory/CLAUDE.md discovery       |
| `--setting-sources u,p,l`     | Restrict which settings files load                                  |
| `--strict-mcp-config`         | Only MCP from `--mcp-config`, ignore everything else                |
| `--plugin-dir` / `--plugin-url` | Load a plugin for this session only                               |
| `--exclude-dynamic-system-prompt-sections` | Move cwd/env/git out of the system prompt for better cache reuse |
| `--tools "Bash,Edit,Read"`    | Restrict the built-in tool set (`""` disables all)                  |
| `--append-system-prompt`      | Add to the default prompt (`--system-prompt` replaces it)           |

Subcommands: `claude agents`, `auth`, `mcp`, `plugin`, `doctor`, `install`, `project`,
`setup-token`, `ultrareview`, `update`.

Gotchas: `--safe-mode` still applies admin policy settings. `--bare` reads auth only from
`ANTHROPIC_API_KEY` / `apiKeyHelper`, never the keychain or OAuth.

---

# codex plugin

The [`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc) plugin — plan in Claude
Code, execute with Codex. Install via `/plugin`, verify with `/codex:setup`
(`--enable-review-gate` to require a fresh review before stop).

## Commands

| Command                     | What it does                                                                           |
| --------------------------- | -------------------------------------------------------------------------------------- |
| `/codex:rescue`             | Delegate a task to Codex via the `codex:codex-rescue` subagent; output returns in-chat  |
| `/codex:transfer`           | Serialize the current session into a resumable Codex thread (`codex resume <id>`)       |
| `/codex:review`             | Read-only Codex review of uncommitted changes (`--base <ref>` to diff a branch)         |
| `/codex:adversarial-review` | Challenges design, tradeoffs and assumptions rather than implementation                 |
| `/codex:status`             | Running and recently-finished Codex jobs for this repo                                  |
| `/codex:result`             | Final output of a finished job, plus its session ID                                     |
| `/codex:cancel`             | Kill a background job (by ID, else the most recent)                                     |

`/codex:rescue` flags: `--background` / `--wait` (default foreground), `--resume` / `--fresh` to
skip the continue-or-new-thread prompt, `--model <model|spark>` (`spark` →
`gpt-5.3-codex-spark`), `--effort <none|minimal|low|medium|high|xhigh>`.

## rescue vs transfer

Same goal, different terminal:

- **`/codex:rescue`** — stay in Claude Code. Good for one-shot execution of a known plan.
  The subagent is a *thin forwarder*: Codex sees only the argument text, **not** the conversation.
  So pass a file path rather than relying on shared context.
- **`/codex:transfer`** — move to the Codex CLI with the planning conversation preloaded.
  Better when execution will be long and interactive.

No need to combine them — pick by where you want to sit.

## Plan-then-execute workflow

`/grilling` composes with plan mode, but **plan mode blocks `Write`** — the markdown plan can only
be written *after* `ExitPlanMode` approval, not during the interview.

```
shift+tab → plan mode
/grilling  — I want to <thing>
… one-question-at-a-time interview …
approve the plan
→ plan written to .claude/plans/<topic>.md
/codex:rescue --background Execute the plan in .claude/plans/<topic>.md
```

Why plan mode for grilling: the skill only *asks* not to act before shared understanding is
confirmed; plan mode makes premature edits structurally impossible. It also forces the plan through
an explicit approval gate instead of leaving "shared understanding" implicit in the chat.

Caveat: `ExitPlanMode` renders the plan in chat, so a long session becomes one big yes/no wall.
Say up front that the deliverable is a file, to keep the exit summary short and the detail in
markdown.

Skip plan mode when grilling a *decision* rather than an implementation — no steps to execute, the
output is a conclusion.
