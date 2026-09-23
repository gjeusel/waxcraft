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

## Extensions

```text
extensions/
├── ask-user-question-format/ compact structured questionnaire results
├── gitleaks-guard/         scan and redact secrets
├── pane-focus/             dim unfocused panes
├── peek-document/          read PDF and Office files
├── per-model-prompt/       model-specific directives
├── pi-builtin-adjustments/ quieter built-ins
├── pi-safety/              Bash command checks, jev auto mode, and safe deletion shims
├── python-code/            sandboxed Python
├── rant/                   log preventable failures
├── statusbar/              minimal one-line footer
└── whimsical/              playful working messages
```

Per-model default effort levels use Pi's native `modelThinkingLevels` setting in `settings.json`,
keyed by exact `provider/modelId`; it applies at startup and on every model switch.

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
├── pi-mcp-adapter/                         MCP server integration
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
request checksum algorithm unchanged. After a standalone package reinstall or update,
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

Use `/no-safety` to disable tree-sitter command checks for the current session.
The rm/rmdir-to-trash routing remains active. After editing shell rules or
extension code, run `/reload` inside Pi. An invalid `pi-safety.jsonc` disables Bash, like a
parser failure, until it is fixed or `/no-safety` is used; a missing one falls back to the
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
