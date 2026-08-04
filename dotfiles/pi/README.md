# pi — earendil-works/pi coding agent

Global config for [pi](https://github.com/earendil-works/pi), stowed to `~/.pi/agent/`.
All files here are **strict JSON** (`JSON.parse`, verified in `settings-manager.ts`) —
no comments allowed, hence this README carrying the annotations instead. GNU Stow
ignores `README.*` by default, so this file is never symlinked into `~`.

## Pi mechanisms worth knowing (vs Claude Code / opencode / codex)

- **Small core by design**: pi intentionally ships *without* built-in MCP, sub-agents,
  permission popups, plan mode, to-dos, or background bash. Everything workflow-shaped
  comes from **extensions/packages** (TypeScript modules with full system permissions —
  review before installing). See the [design blog post](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/).
- **Config layering**: `~/.pi/agent/settings.json` (global) ← `.pi/settings.json`
  (project, nested objects merged). Project resources only load after the **trust
  prompt** (`/trust`, stored in `~/.pi/agent/trust.json` — machine state, like codex's
  `[projects]` table; `defaultProjectTrust: "ask"` keeps the prompt).
- **`/reload`** applies keybindings/permissions/settings edits without restarting.
  The active theme hot-reloads on file save.
- **First run**: `pi` auto-installs the `packages` listed in settings under
  `~/.pi/agent/npm/` (needs npm on PATH). Auth is via `/login` or `pi auth` — creds
  land in `~/.pi/agent/auth.json` (0600, NOT stowed; also in the permissions deny list).

## settings.json

- `theme: "nord"` → `themes/nord.json` (custom, all 51 tokens from the Nord palette;
  same palette as opencode's `rnx-nord`). Themes need every token defined — the
  `$schema` field gives editor completion.
- `skills`: pi natively scans `~/.pi/agent/skills/`, `~/.agents/skills/`, and project
  `.agents/skills`/`.pi/skills` (after trust). The `"~/.claude/skills"` entry adds the
  Claude Code skills on top — pi implements the same Agent Skills standard, so they
  work as-is and register as `/skill:<name>` commands (`enableSkillCommands`).
  Claude *plugin marketplace* skills (`~/.claude/plugins/marketplaces/*/skills`) are
  not included — most are plugin-specific; add a glob entry if ever needed.
- **/rewind**: the `@ayulab/pi-rewind` package provides real Claude Code-style rewind —
  git-shadow checkpoints captured around each turn, `/rewind` restores code and/or
  conversation (its `ayu.rewind.restoreOnTree: "ask"` default also hooks the built-in
  `/tree` navigation). The built-in `/tree` (double-Escape) alone only rewinds the
  conversation, never files.
- `quietStartup: true` → **empty home page**: suppresses the startup header AND the
  whole loaded-resources listing (context files, skills, prompts, themes, extensions)
  — verified in `interactive-mode.ts` `showLoadedResources()`, which returns early
  unless `--verbose` is passed. Everything still loads, it's just not printed.
- `defaultThinkingLevel: "high"` — initial level for new sessions. Cycle at runtime
  with Shift+Tab; the editor border color indicates the level (see theme `thinking*`
  tokens). Runtime changes stay session-local via `session-only-model-selection.ts`.
- No `defaultProvider`/`defaultModel` pinned: pick with Ctrl+Shift+L (remapped, see
  below) after authenticating; pi persists the last used model per project.
- `packages` beyond `pi-mcp-adapter` (permissions is vendored, see below):
  - `pi-claude-bridge` — exposes Claude Code subscription models under the
    `claude-bridge/*` provider and adds the `AskClaude` delegation tool
  - `pi-subagents` — Agent-tool equivalent (delegation, parallel, chains)
  - `@plannotator/pi-extension` — interactive plan review with annotations
  - `@narumitw/pi-lsp` — LSP diagnostics/fix tools, configured via `pi-lsp.json` (below)
  - `pi-web-access` — web search + page fetching (pi has no built-in WebSearch)
  - `@ayulab/pi-rewind` — /rewind with file checkpoints (see above)
  - `@juicesharp/rpiv-ask-user-question` — structured interactive questionnaires
    so the model can clarify decisions instead of guessing
  - `@juicesharp/rpiv-todo` — a persistent todo tool and live task overlay that
    survives `/reload` and conversation compaction
  - `@ff-labs/pi-fff` — FFF-powered fuzzy file/content search and `@` file
    autocomplete with background indexing and frecency ranking

## claude-bridge.json (pi-claude-bridge package)

The `pi` shell function in `zsh/aliases.zsh` unsets `ANTHROPIC_API_KEY` for the
Pi process so Claude Code uses its `claude.ai` OAuth session. Otherwise an exported
API key takes precedence, and an invalid/stale key causes repeated 401 retries that
look like a hung request. Authenticate or verify the subscription session with
`claude auth login` and `claude auth status`.

`provider.plan: "max"` enables the entitled 1M context for Opus 4.6 without Extra
Usage. `longContextExtraUsage: false` avoids paid Extra Usage; Fable 5, Opus 5,
Opus 4.8/4.7, and Sonnet 5 still use their default 1M context. In pi, select a
`claude-bridge/*` entry with `/model` (Ctrl+Shift+L), then prompt normally. The
same package also exposes `AskClaude` while another provider is selected.
Set `CLAUDE_BRIDGE_DEBUG=1` before launching pi to write bridge diagnostics to
`~/.pi/agent/claude-bridge.log` and Claude CLI logs to
`~/.pi/agent/cc-cli-logs/`.

## pi-lsp.json (@narumitw/pi-lsp package)

Declaring `servers` REPLACES the built-in catalog, so only these run:
`ty` + `ruff` for Python, `typescript-language-server` (via `npx -y`, so it uses the
project's own `typescript`) for JS/TS. Servers spawn per tool call and shut down
after; binaries must be on PATH (`ty`/`ruff` are, via uv tools).

Deliberately NOT here: **oxlint** has no standalone language server on npm (the oxc
LSP binary only ships inside the VS Code extension) and **oxfmt** is a formatter with
no LSP at all — both stay CLI commands run by the agent.

## permissions.json (extensions/permissions/ — vendored pi-permissions)

Pi has **no built-in permission system** — `extensions/permissions/` provides it:
a vendored fork of `npm:pi-permissions@1.0.4` (164 lines, MIT). Vendored for one
reason: the npm package hardcodes a "Permissions loaded: N allow, M deny rules"
chat notification on every session start with no way to silence it. The fork
replaces that with `ctx.ui.setStatus("permissions", "⛨N")`, rendered by the
statusbar extension (see below). `rules.ts` is untouched upstream code; check
the npm package occasionally for upstream fixes. Semantics differ from Claude Code:

- There is **no "ask"** tier — rules only `allow` or `deny` (matching deny = hard
  block before execution). Combined with pi's no-popup philosophy this *is* the
  "auto mode": everything runs, except the deny list.
- Evaluation: deny first (always wins) → allow rules *only if any exist for that
  tool* → otherwise pass through. Keeping `allow: []` empty is what makes it
  "allow all, except …" — adding a single `Bash(...)` allow rule would flip Bash
  to whitelist-only mode. Don't.
- Rules are `Tool(glob)` with tools `Bash|Read|Write|Edit`; `*` crosses everything
  including `/`. `Bash(*.ssh/*)` therefore blocks *any* command string mentioning
  the path (cat/grep/jq/...), same substring trick as the opencode config.
- The deny list mirrors `~/.claude/settings.json` + opencode: git push, direct
  `rm`/`mv` (including `git rm`/`git mv`), sudo, env-dumping, kubectl/helm
  mutations (reads stay allowed by omission), credential stores, key material,
  shell history, `*renewex.yaml`, `*.tfvars`, and the agents' own credential
  files (including pi's `auth.json`).
- Loaded once at session start — `/reload` after edits.

## mcp.json (pi-mcp-adapter package)

No built-in MCP either; `pi-mcp-adapter` bridges it with a twist: instead of
registering every tool schema (10k+ tokens/server in Claude Code), it exposes ONE
`mcp` proxy tool (~200 tokens) with on-demand search/describe/call — same spirit as
Claude Code's deferred ToolSearch. Servers are **lazy**: they only spawn on first
call.

- Config precedence: `~/.config/mcp/mcp.json` > `~/.agents/mcp.json` > this file
  (`~/.pi/agent/mcp.json`) > project `.mcp.json` > `.pi/mcp.json`. We use the
  pi-owned global file so stow owns it without clashing with other tools.
- Headers/env support `${VAR}` interpolation → `EXCALIDRAW_MCP_TOKEN` must be in the
  environment (kept out of the repo; the raw token currently lives in `~/.claude.json`).
  A leading `!cmd` in a header value shells out for the secret at connect time —
  alternative if you prefer `!security find-generic-password ...`.
- `postgres` pins `mcp<2` (postgres-mcp crashes on mcp>=2 — see
  https://github.com/crystaldba/postgres-mcp/issues/187, same pin as codex/opencode).
- `/mcp` lists servers, `/mcp disable <server>` persists to project `.pi/mcp.json`.
- `cloudflare-api` is `"disabled": true`: OAuth-protected remote server (401
  without a token — Claude Code runs their OAuth flow transparently). To
  re-enable, remove the flag and add `"auth": "oauth"` — the adapter then runs
  the authorization-code flow on first connect.
- `GitLab` uses [zereight/gitlab-mcp](https://github.com/zereight/gitlab-mcp)
  (the builtin `gitlab.com/api/v4/mcp` OAuth flow didn't work). The
  `zereight-mcp-gitlab` binary is installed via its homebrew tap (pinned in
  `nix/flake.nix`, brew in `nix/homebrew.nix`). Requires
  `GITLAB_PERSONAL_ACCESS_TOKEN` (scope `api`) in the environment; runs with
  `GITLAB_PERMISSION_MODE=modify` (create/update allowed, all delete tools blocked).
- Since the adapter is one cheap proxy tool, keeping chrome-devtools + playwright
  listed costs ~nothing (unlike opencode where they were dropped for ~10k tokens/turn).

## keybindings.json

Key format is single `modifier+key` combos — **no chord/sequence support** (checked
`packages/tui/src/keys.ts`), so shell-style `ctrl+x ctrl+e` can't exist:

- **Edit prompt in $EDITOR**: `ctrl+x` (plus default `ctrl+g`) → `app.editor.external`,
  the closest single-key match to the readline ctrl-x ctrl-e habit. Uses
  `$VISUAL`/`$EDITOR` (nvim), or set `externalEditor` in settings.json.
  `app.message.copy` (default ctrl+x) moved to `ctrl+shift+x`.
- **Vim-ish movement** without alt (the docs' vim example uses alt+hjkl, but alt is
  eaten as Meta/esc-prefix in most macOS terminals): `ctrl+h/j/k/l` for
  left/down/up/right, `ctrl+b`/`ctrl+f` for word-left/word-right.
  Conflicts that had to move:
  - `ctrl+j` was newLine → newLine is `shift+enter` only now
  - `ctrl+k` was deleteToLineEnd → `ctrl+shift+k`
  - `ctrl+l` was model select → `ctrl+shift+l`
  - `ctrl+h`: terminals without the kitty keyboard protocol send backspace for
    ctrl+h — fine in ghostty/kitty/WezTerm, degrade gracefully elsewhere.
- **`ctrl+p`/`ctrl+n` = previous/next** everywhere: cursor up/down in the editor
  (`tui.editor.*`) AND list navigation in pickers/autocomplete (`tui.select.*`).
  Displaced defaults: model cycle (was ctrl+p / ctrl+shift+p) → `ctrl+shift+p` /
  `ctrl+shift+n`; in the /resume picker, path toggle (was ctrl+p) → `ctrl+shift+r`
  and named-filter (was ctrl+n) → `ctrl+shift+f`. The path toggle avoids
  `ctrl+shift+t`, which `rpiv-todo` uses to collapse its overlay.
- Everything else keeps defaults: Escape interrupt, double-Escape tree/rewind,
  `shift+tab` thinking level, `ctrl+o` expand tools, `!` prefix for bash mode.
- **Real vim editing**: the `pi-vim` package (npm:pi-vim) turns the prompt into a
  modal editor — INSERT/NORMAL/VISUAL/V-LINE, text objects (`ci"`, `da{`), counts,
  `.` repeat, vim-scoped undo, and an ex line that dispatches pi commands
  (`:tree`, `:model opus`, `:!git status`) with draft snapshot/restore. Esc enters
  NORMAL instead of interrupting; the keybindings above still apply in INSERT mode.

## extensions/session-only-model-selection.ts

Keeps model and thinking-level changes session-local. Pi normally writes each runtime
selection back to `defaultProvider`, `defaultModel`, and `defaultThinkingLevel` in
`settings.json`; this extension suppresses those settings-manager writes while still
letting session history record and restore the active selections. The authored defaults
therefore remain stable across Shift+Tab thinking changes and model picker selections.

## extensions/gitleaks-guard.ts

Custom extension (auto-discovered from `~/.pi/agent/extensions/*.ts`, hot-reload
with `/reload`). Hooks the `input` event: every message headed for the prompt —
typed, pasted, rpc, or extension-injected — is piped to `gitleaks stdin` first.
On a finding the message is **blocked** before reaching the LLM and the redacted
findings are shown; resending the *exact same text* bypasses the guard (escape
hatch for false positives). Fail-open: if `gitleaks` is missing or errors, the
prompt goes through with a warning. Requires `gitleaks` on PATH (installed via
nix). Uses `spawnSync` rather than `pi.exec` because the latter can't feed stdin.

## extensions/safe-trash.ts

Native pi equivalent of Claude's `hooks/safe_trash.sh`. It injects a system-prompt
rule telling the model to use macOS `trash` instead of `rm`, and blocks direct or
compound `rm`, `mv`, `git rm`, and `git mv` Bash calls. Common nested shell,
`find`, and `xargs` forms are blocked too. Every direct `trash` target is validated.
Temp paths are exempt; filesystem roots, system paths, top-level home paths, and
protected home config directories are denied. Dynamic paths, traversal, command
substitutions, quotes, braces, wrappers, and `cd … && trash …` fail closed. Both
lexical and symlink-resolved paths are checked. The matching permission rules
provide defense in depth for simple direct commands.

## extensions/statusbar.ts

Replaces the built-in footer (2–3 lines: pwd+branch, token/cost stats, extension
statuses such as the MCP adapter's) with a single minimalist line via
`ctx.ui.setFooter()` on `session_start`:
`<repo path> (<branch>)`, `<model> · <thinking level>`, `<context %>`
justify-between'd across the width, everything in the same dim gray. Token counts, cost,
cache stats, and MCP/extension statuses are deliberately dropped — with one
exception: the `permissions` status key (the `⛨N` deny-rule count from the
vendored permissions extension) is shown next to the context %. `⛨0` there
means permissions.json failed to load — investigate.
`@earendil-works/pi-tui` (`truncateToWidth`/`visibleWidth`) is a runtime import —
fine, the extension loader aliases it to pi's bundled copy.

## extensions/exit-resume-command.ts

Rewrites pi's verbose exit hint from `To resume this session: pi --session <id>`
to the single dim-gray line `pi --session <id>`. Pi emits the built-in hint only
after extension shutdown has completed and exposes no setting or renderer for it,
so the extension installs a narrowly scoped stdout interceptor during a real quit.
Only the exact built-in resume-hint shape is rewritten; other shutdown output and
non-quit session replacements pass through unchanged.

## extensions/pane-focus.ts

Adds tmux focus feedback to pi's input editor. While this tmux pane, its window,
and its client are focused, the two horizontal editor borders keep the active
thinking level (or bash mode) color. On `FocusOut`, only those borders switch to
the same `dim` gray used by the custom status bar; `FocusIn` restores the live
mode color. The extension enables terminal focus reporting (`DECSET 1004`),
consumes the resulting escape sequences through `ctx.ui.onTerminalInput()`, and
composes with any editor factory installed before it. `focus-events on` must
also be set in tmux so pane changes are forwarded to pi (configured in
`.tmux.conf`); run `tmux source-file ~/.tmux.conf` once for an existing server.

## extensions/python-code.ts

Registers the `python` tool (shown as **Python Code Tool**) for self-contained,
dependency-free Python snippets. Source is passed directly in the tool's `code`
argument (stdin-style); callers must not create a `.py` file. Every call uses a
fresh crash-isolated Monty worker session with no filesystem, network, environment,
host-tool, or third-party package access. Runs are capped at 10 seconds, 64 MiB, and 50 KB / 2000 output
lines. Monty limitation-like errors tell the model to retry with normal Python via
`bash`; ordinary Python errors keep their traceback and do not trigger that fallback.

## Editor tooling and runtime dependencies for extensions/

The extensions dir carries a `tsconfig.json` (NodeNext, strict, noEmit — mirrors
pi's own tsconfig.base), a `package.json` declaring pi's packages and TypeScript
types for editor/LSP comfort, and the Monty/TypeBox runtime dependencies used by
`python-code.ts`. The `.oxfmtrc.json` supplies formatter config. These files are
**source tooling, not pi config**, so `.stow-local-ignore` keeps them (plus
lockfiles, `node_modules/`, and the `tests/` directory) out of
`~/.pi/agent/extensions/` — only runtime extension files are stowed.
Run the install **in this repo directory** (`npm install` or `pnpm install` here).
The Python Code Tool resolves its dependencies beside the real (pre-symlink)
extension source, while the install also gives the LSP all required types.
`tsc -p . --noEmit` passes clean.

## Stow gotcha: --adopt vs pi's own writes

The justfile stows with `--adopt`: if pi already created a real file at a target path
(it writes `settings.json` on first run), adopt MOVES that runtime file into this
package, silently overwriting the authored config — exactly what happened on first
stow. Rule of thumb: stow BEFORE the first `pi` launch, or check `git diff` on this
package right after stowing. Also note pi rewrites `settings.json` in place at runtime
(`lastChangelogVersion`, `/settings` changes; model/thinking persistence is suppressed
by `session-only-model-selection.ts`) — through
the symlink, so churn in this file is expected, same as codex's trust table.
`auth.json`, `models-store.json`, `sessions/`, `trust.json` are machine state and
intentionally not stowed.

## Setup after stow

```bash
npm i -g @earendil-works/pi   # or: brew install pi (check their docs)
pi                            # first run: auto-installs the npm packages from settings.json
/login                        # authenticate provider(s) — writes ~/.pi/agent/auth.json
# LSP types for custom extensions (in the repo, not in ~):
(cd ~/src/waxcraft/dotfiles/pi/.pi/agent/extensions && npm install)
```

Startup is fully quiet; the statusbar's `⛨N` confirms the deny rules loaded.
