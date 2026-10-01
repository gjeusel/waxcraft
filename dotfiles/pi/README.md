# pi

Personal [Pi](https://pi.dev) configuration, stowed to `~/.pi/agent/`.

## Setup

Run this **before the first Pi launch** so `stow --adopt` cannot replace the tracked configuration with files created by Pi:

```bash
cd ~/src/waxcraft
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
just stow-install
pi
```

Then, inside Pi:

```text
/login
/model
```

The Hunk review skill is loaded directly from the installed `hunkdiff` package so it stays aligned with Hunk upgrades. Verify its configured path after changing Hunk's installation method:

```bash
hunk skill path
```

After upgrading Hunk, start a new Pi session or run `/reload` before reviewing a live Hunk session.

Subagent `skills:` preloading (`.pi/agent/agents/*.md`, e.g. the reviewer's `code-review`) is resolved by `pi-subagents`, which rejects symlinked skill directories. The symlinks in `~/.pi/agent/skills/` are skipped and resolution falls through to the real directories in `~/.agents/skills/`; keep those real, or the agent silently runs with a `(Skill "…" not found)` placeholder in its prompt.

Pi installs the packages from `settings.json` on first launch. [Pi Black](https://github.com/paoloanzn/pi-black)
wraps the native Anthropic provider for Claude subscription OAuth requests; it does not run a
Claude Code subprocess. Authenticate inside Pi and select an `anthropic/claude-*` model:

```text
/login anthropic
/model
```

Pi Black requires Pi 0.84.1 or newer. Its Claude Code request compatibility is version-specific
and unofficial; revalidate subscription access when upgrading. API-key requests remain unchanged.

## Mistral EU inference

`models.json` registers `mistral-eu/zai-glm-5-3` using `MISTRAL_API_KEY` from the environment.
Select it inside Pi (opening `/model` reloads `models.json`):

```text
/model mistral-eu/zai-glm-5-3
```

Or start a new session:

```bash
pi --provider mistral-eu --model zai-glm-5-3
```

The separate provider targets only `https://api.eu.mistral.ai`, with no global fallback, and leaves
Pi's built-in `mistral` provider and default model unchanged. It uses Pi's native
`mistral-conversations` transport for Chat Completions, including streamed reasoning and function
calls; this transport appends `/v1/chat/completions`, so the base URL must not include `/v1`.

[GLM 5.3](https://docs.mistral.ai/models/zai-glm-5-3) is text-only, with a 1,048,576-token context
(confirmed by the EU models API) and 131,072-token maximum output. Configured USD prices per million
tokens include the [regional 10% surcharge](https://docs.mistral.ai/en/inference/regional-inference):
$1.54 input, $0.154 cached input, and $4.84 output. Regional inference concerns inference processing,
not all control-plane data or zero data retention. Model availability is region-specific; recheck
`GET https://api.eu.mistral.ai/v1/models` before adding models from the
[Mistral catalog](https://docs.mistral.ai/models).

## MCP servers

`mcp.json` configures Pi's built-in [MCP support](https://pi.dev/docs/latest/mcp) (Pi 0.99+). Do not
install `pi-mcp-adapter` again: an extension that registers `/mcp` disables the built-in support.
The file is plain JSON (no comments). Servers use the default `codemode` exposure, and HTTP servers
without an `Authorization` header sign in with OAuth, with tokens stored in `~/.pi/agent/mcp-auth.json`:

```bash
pi mcp list                # connect to every enabled server and report its state
pi mcp login <server>      # browser sign-in for servers reported as "needs sign-in"
```

`pappers` and `excalidraw` authenticate with bearer tokens from `PAPPERS_API_KEY` and
`EXCALIDRAW_MCP_TOKEN`. `auth0` keeps its credentials in the macOS Keychain; refresh them with
`npx -y @auth0/auth0-mcp-server init` (device login) when `pi mcp list` reports an expired token.

Servers whose configuration `mcp.json` cannot express, such as values Pi does not expand from
`${VAR}` (only `env`, `headers`, and `oauth.clientSecret` are), are registered by the
`complex-mcp-setup` extension instead, one function per server. `pi mcp list` and `pi mcp login` do
not load extensions: check and sign in to these servers with `/mcp` inside a session.

`slack` (in `complex-mcp-setup`) is Slack's official server. It has no dynamic client registration,
so it signs in through the personal internal Slack app `pi-slack-mcp` (no secret: PKCE is opted
in), whose client ID comes from `SLACK_MCP_CLIENT_ID` (exported in `~/.zshrc`, unversioned) because
Pi does not expand `${VAR}` in `oauth.clientId`. The app requests every user scope listed in
[`oauth-protected-resource`](https://mcp.slack.com/.well-known/oauth-protected-resource) (Pi requests
them all, so a scope Slack adds later must be added to the app too), has its redirect URL set to
`http://localhost:3118/callback` to match `callbackUrl`, has Model Context Protocol enabled under
*Agents & AI Apps*, and declares a never-used bot user, without which Slack's user-authorize endpoint
rejects the request. Slack's own Pi guide points to `pi-mcp-adapter`; ignore it (see above).

`aws` is the managed [AWS MCP Server](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html)
(`eu-central-1` endpoint, the closest supported region) behind `mcp-proxy-for-aws`, which signs
requests with SigV4 using the `rnx-readonly` profile from `~/.aws/credentials` (IAM user with
`ReadOnlyAccess`; the server needs no MCP-specific IAM actions). `--read-only` hides write-capable
tools, and `AWS_REGION=eu-west-1` makes Renewex's region (`rnx-cluster`) the default for API calls.
The explicit `--profile` also stops boto3 from using the stale `AWS_ACCESS_KEY_ID` exported by the
shell.

## Extensions

```text
extensions/
├── artifacts/              publish HTML/Markdown pages locally (Claude Code artifacts)
├── ask-user-question-format/ compact structured questionnaire results
├── auto-name/              name sessions once they get long, or on a bare /name
├── complex-mcp-setup/      MCP servers mcp.json cannot express (see MCP servers)
├── gitleaks-guard/         scan and redact secrets
├── pane-focus/             dim the editor in unfocused tmux panes or terminals
├── peek-document/          read PDF and Office files
├── per-model-prompt/       model-specific directives
├── pi-builtin-adjustments/ quieter built-ins
├── pi-safety/              Bash command checks, jev auto mode, and safe deletion shims
├── python-code/            sandboxed Python
├── rant/                   log preventable failures
├── statusbar/              minimal one-line footer
└── whimsical/              playful working messages
```

### Artifacts

A local take on [Claude Code artifacts](https://code.claude.com/docs/en/artifacts), which are a
built-in Claude Code tool hosting pages on claude.ai. The `publish_artifact` tool renders an `.html`,
`.htm`, or `.md` file into `~/.pi/agent/artifacts/<id>/` and serves it at
`http://127.0.0.1:7424/<id>/` (the gallery is at `/`). Republishing the same file or `artifact_id`
updates the page in place and open tabs live-reload. The server lives in whichever Pi session binds
the port first; later sessions reuse it, and a new one takes over when that session exits.

The first publish opens the browser (`PI_ARTIFACT_AUTO_OPEN=0` disables this), `Ctrl+]` reopens the
session's latest artifact (so `keybindings.json` unbinds the editor's `jumpForward`), and
`/artifacts` lists artifacts to open, copy, or attach to the session. The bundled `artifact-design`
skill carries the page-building guidance.

Per-model default effort levels use Pi's native `modelThinkingLevels` setting in `settings.json`,
keyed by exact `provider/modelId`; it applies at startup and on every model switch.

### Auto-name

When the context of an unnamed session reaches `thresholdTokens`, a background request sends its user
and assistant text (no thinking or tool output) to `model` and sets the reply as the session name
shown in `/resume`, the terminal title, and the statusbar. A reply over six words goes back to the
model once to drop its secondary part; if still too long, it is cut before a secondary clause (after
a comma, or at a word such as "and" or "with"). Existing names from `/name <name>`, `--name`, or
subagents are kept, and a name set while the request runs wins. Each session runtime tries once: a
failure is reported as a warning and retried only in a later runtime of the session (`/reload`,
`/resume`, or a restart).

A bare `/name` does the same on demand, at any context size, and replaces the current name; the
notification shows the previous one. `/name <name>` still sets the name. Pi handles `/name` before
extension commands, so the extension catches the Enter that submits a bare `/name`, typed in full or
picked from the autocomplete list; this works in the interactive TUI only.

`auto-name.json` sets `thresholdTokens` (default `50000`) and `model` (default
`openai-codex/gpt-6-luna`). A missing file uses the defaults; an invalid one disables auto-naming
with a warning. It is read at session start, so run `/reload` after editing it.

### To Checkup

- [pi-agents-tmux](https://github.com/vanillagreencom/kendex/tree/main/pi-extensions/pi-agents-tmux)
- [deputies](https://github.com/sidpalas/deputies)
- [dsh-import-agents](https://github.com/Chang-Tong/dsh-import-agents)
- [tintinweb/pi-tasks](https://github.com/tintinweb/pi-tasks)

### Already Tested

- [pi-intercom](https://github.com/nicobailon/pi-intercom) not great, polluting more than anything
- [pi-subagents](https://github.com/nicobailon/pi-subagents) not great, unsure it's the proper way to do it
- [juicesharp/rpiv-todo](https://github.com/juicesharp/rpiv-mono/tree/main/packages/rpiv-todo) very good !

## Packages

Third-party packages are pinned in `settings.json`. Pi Black uses the GitHub release
`v0.84.1-cc2.1.258.1`, with a local protocol-version patch to advertise Claude Code `2.1.280`
(the minimum required for Opus 5.5). This is an unofficial compatibility override, not an upgrade
of Claude Code; revalidate it when either service changes. Claude model definitions, including
Fable 5.1, come from Pi's native
Anthropic catalog; the reviewer uses `anthropic/claude-fable-5-1`.

`models.json` adds `anthropic/claude-opus-5-5` until it reaches the native catalog, retaining
existing Anthropic authentication and Pi Black compatibility. It is included in model cycling,
with medium effort by default and always-on adaptive thinking. The definition uses the
[official limits](https://platform.claude.com/docs/en/models/opus-5-5/overview) (1M context,
128K output) and [pricing](https://platform.claude.com/docs/en/about-claude/pricing) ($4 input,
$20 output, $0.20 cached input, $5 cache write per million tokens). Select it with:

```text
/model anthropic/claude-opus-5-5
```

```text
packages/
├── pi-black/                               native Anthropic OAuth compatibility
├── pi-subagents/                           delegated agent workflows
├── pi-intercom/                            cross-session communication
├── @narumitw/pi-lsp/                       language-server diagnostics and fixes
├── @narumitw/pi-codex-compact/             Codex-aware context compaction
├── @narumitw/pi-usage/                     provider usage and quota display
├── pi-web-access/                          web search and content retrieval
├── arpagon/pi-rewind/                      conversation checkpoints and rewinding
├── @juicesharp/rpiv-ask-user-question/     structured user prompts
├── @juicesharp/rpiv-todo/                  task tracking
├── @ff-labs/pi-fff/                        fast file and content search
```

## Maintenance

```bash
cd ~/src/waxcraft
just pi-install
(cd dotfiles/pi/.pi/agent/extensions && npm test)
pi update --all
```

`just nix-up` switches the Nix system first, then runs `just pi-install`. The
installer uses the flake's supported Node.js version for `npm ci` and stows
`~/.local/bin/pi`.

`just pi-install` also reapplies the tracked patches in `.pi/agent/patches/` for
foreground-only subagent labels (agent `color` sets text color without badge
padding or background changes) and Pi Black's Claude Code `2.1.280` version override.
The latter updates the shared constant used by the user-agent, billing header, and version
fingerprint, plus the upstream fingerprint test fixtures; it leaves the billing salt and
request checksum algorithm unchanged. It also moves host-provided modules (TypeBox, Pi packages)
from installed extension packages' `dependencies` to `"*"` peerDependencies, which silences Pi's
"Host-provided extension packages" warning for packages that have not fixed their manifests
upstream; Pi's loader aliases these imports to its own copies either way. After a standalone
package reinstall or update,
reapply and verify them with:

```bash
dotfiles/pi/.pi/agent/patches/apply.sh
node --test dotfiles/pi/.pi/agent/patches/*.test.mjs
```

Keep the extensions' `@earendil-works/pi-coding-agent` and `@earendil-works/pi-tui`
devDependencies on the installed Pi minor version (`pi --version`); otherwise typecheck and
tests validate an API the runtime no longer has.

The patch tests use the installed subagent package and the extensions' TypeScript
dependency. Restart Pi or run `/reload` after applying patches. If an upstream
change makes a patch incompatible, the installer fails rather than silently
skipping it; refresh the patch when upgrading that package.

If the current shell still resolves the pnpm launcher, prepend `~/.local/bin`
and clear Zsh's command cache with
`export PATH="$HOME/.local/bin:$PATH"; rehash`. Shell-command rules are a
best-effort guardrail: tree-sitter evaluates literal command names, while
dynamically constructed executable names remain intentionally unresolved.

`paths` rules in `pi-safety.jsonc` guard the `write` and `edit` tools: `deny` globs block
(credential directories), `ask` globs need a confirmation, blocked without a UI (the safety
policy itself, shell startup files, `.env`). Both the given path and its symlink-resolved path
are matched, so stowed files are covered through `~` and the repository. Bash writes to the same
paths are not inspected.

Use `/no-safety` to disable tree-sitter command and protected-path checks for the current
session. The rm/rmdir-to-trash routing remains active. After editing shell rules or
extension code, run `/reload` inside Pi. An invalid `pi-safety.jsonc` disables Bash, `write`, and
`edit`, like a parser failure, until it is fixed or `/no-safety` is used; a missing one falls back to the
built-in safeguards. The statusbar shows these degraded states (`🛡 config invalid`,
`🛡 defaults`, `🛡 disabled`, `🛡 parser error`) before the context percentage.

### Auto mode

`/toggle-auto-mode` adds a [pi-verdict](https://github.com/jesset/pi-verdict)-style permission
gate on top of the shell rules: every model-generated Bash command that the rules let through is
sent, together with a condensed transcript (recent user messages and tool calls, no tool results),
to TypeSafe's [jev](https://docs.typesafe.ai) decisions model, which answers `allow`, `ask`, or
`deny` with calibrated probabilities. `allow` runs silently, `deny` blocks with a notification, and
`ask` opens a confirmation dialog. A verdict below `autoMode.minConfidence` (`pi-safety.jsonc`,
default `0.5`) is demoted to `ask`, and so is an unreachable classifier; without a UI, `ask`
becomes a block so nothing runs silently.

Auto mode is off by default and session-scoped; `PI_AUTO_MODE=1` starts it on. It needs
`TYPESAFE_AI_API_KEY` in the environment. While on, the statusbar shows `auto-mode` before the
context percentage.
