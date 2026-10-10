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

Subagent `skills:` preloading (`.pi/agent/agents/*.md`, e.g. the reviewer's `code-review`) is resolved by `pi-subagents` from `~/.agents/skills/`. The reviewer's `code-review` is a customized fork versioned in `dotfiles/agents/.agents/skills/code-review` (not installed with `npx skills`); its stowed directory symlink resolves correctly. If a preloaded skill stops resolving after a `pi-subagents` upgrade, the agent silently runs with a `(Skill "…" not found)` placeholder in its prompt.

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
├── pi-openai/              Codex Fast mode and direct server-side compaction
├── pi-safety/              Bash command checks, decisions auto mode, and safe deletion shims
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

### Pi OpenAI

`pi-openai` replaces `@narumitw/pi-usage` and `@narumitw/pi-codex-compact` for the official
`openai-codex` provider. It makes no usage/quota queries and has no model allowlist.

- `/fast` toggles priority routing; `/fast on`, `/fast off`, and `/fast status` are also available.
  The preference is saved in `~/.pi/agent/pi-openai.json` (`fastMode`, default `false`); this
  repository configures it to `true`. The footer shows `fast` while effective. Fast sends
  `service_tier: "priority"`, uses more plan allowance, and remains subject to backend support.
  Off explicitly sends `service_tier: "default"`. Changes affect subsequent requests only.
- `/codex-compact` immediately starts server-side Remote V2 compaction: no menu or confirmation.
  Pi's `/compact` and automatic threshold/overflow compaction use the same server operation on
  this provider. The active conversation and system prompt are sent with a final
  `compaction_trigger`; an encrypted checkpoint replaces the older context and is replayed on
  subsequent compatible requests.

Server compaction requires the official Codex Responses endpoint and backend entitlement. A
failure cancels compaction without replacing context or making a plaintext-summary request.
Other providers keep Pi-native compaction when no opaque checkpoint is active. There is no
fallback from an opaque checkpoint to a plaintext placeholder summary.

Existing Codex `pi-codex-compact` checkpoints remain readable. Checkpoints still require their
exact producing model/API for replay: other models only see the retained recent messages and a
warning about unavailable older context. Return to the original model to replay it. Retain this
extension for sessions with opaque history. The old `pi-usage.json` and `pi-codex-compact.json`
settings are no longer used.

After adding the extension, restow the Pi package and run `/reload`; reload alone cannot discover
files that have not been linked into `~/.pi/agent/` yet.

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
Anthropic catalog; the reviewer uses `openai-codex/gpt-6-astra` with high thinking.

`models.json` overrides `openai-codex/gpt-6.1-sol` and `openai-codex/gpt-6-luna` to use
1,000,000-token contexts, retaining Pi's native output limits, pricing tiers, and capabilities.
`gpt-6-astra` keeps Pi's default context limit. These overrides opt into long contexts; the
Codex backend must support them, and inputs above 272,000 tokens enter the higher pricing tier.
Other OpenAI and Anthropic model definitions come from Pi's native catalog. The custom Mistral EU
endpoint and OpenRouter Ox Alpha definition remain in `models.json`.

```text
packages/
├── pi-black/                               native Anthropic OAuth compatibility
├── pi-subagents/                           delegated agent workflows
├── pi-intercom/                            cross-session communication
├── @narumitw/pi-lsp/                       language-server diagnostics and fixes
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
padding or background changes), persistence-independent worker safety linkage, and Pi Black's
Claude Code `2.1.280` version override.
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

Auto mode adds a [pi-verdict](https://github.com/jesset/pi-verdict)-style permission gate on top
of the shell rules. It is **enabled by default**, using OpenAI's
[Decisions API](https://developers.openai.com/api/docs/guides/decisions) with `gpt-6-luna`.
Every model-generated Bash command that the rules let through is sent with a condensed transcript
(recent user messages and tool calls, no tool results) to the selected backend.

Configure `autoMode` in `pi-safety.jsonc` and run `/reload`:

```json
"autoMode": {
  "enabled": true,
  "source": "openai",
  "minConfidence": 0
}
```

- `openai` uses `POST https://api.openai.com/v1/decisions` and requires `OPENAI_API_KEY` in the
  environment (not Pi's Codex subscription login).
- `jev` uses TypeSafe's [jev](https://docs.typesafe.ai) `jev-latest` model and requires
  `TYPESAFE_AI_API_KEY`. Change `source` to `"jev"` to select it; there is no automatic fallback.

Both backends use the same permissive criteria: **allow plausible task-related work unless there
is a concrete substantial risk**, even with some uncertainty. Ordinary edits, installs, downloads,
API calls, local Git operations, and generated-file cleanup should not need approval merely because
they have side effects. Substantial destructive, security, or external-impact risks still prompt;
clearly dangerous actions (such as secret exfiltration or indiscriminate destruction) are denied.
Infrastructure mutations and remote execution are explicitly classified as `ask`, including
Kubernetes changes/exec, Helm changes, Terraform apply/destroy, and cloud compute/network/IAM
changes—even when task-related or explicitly requested. Read-only infra inspection and local
configuration edits without applying them remain ordinary work.

`allow` runs silently, `deny` blocks with a notification, and `ask` offers Allow / Deny.
`minConfidence` defaults to `0`, so uncertainty alone does not add a prompt or override a verdict.
Set it higher (for example, `0.5`) to demote low-confidence allow/deny verdicts to `ask`.
Request failures, refusals, and malformed answers still require confirmation. A valid refusal is
reported as **classification refused**, not **classifier unavailable**; OpenAI supplies no refusal
explanation, so the message includes its request ID when available. There are no automatic retries
or backend fallbacks. The classifier explicitly assesses only the proposed command: historical tool
calls are context, and reading a workflow or safety document does not execute or disable anything.
A missing API key leaves the gate enabled and blocks commands that need classification rather than
silently bypassing it.

The kubectl/Helm mutation rules carry `autoMode: "ask"`: with auto mode **on**, they require explicit
approval even if the classifier returns `allow`; with auto mode **off**, they remain hard denies.
The classifier still checks the full command and can deny other dangerous effects. A rule-based ask
never hides another hard deny in the same command or nested script. Other deterministic rules and
protected-path confirmations are unchanged.

`/toggle-auto-mode` immediately toggles the gate for the current session and its linked workers,
including already-running workers and later tool calls in the **current response**. In-flight
classifications and pending auto-mode approvals are cancelled, and the affected command is checked
again under the new mode before it can run. Off/on races cannot authorize from an old verdict.
Turning the gate off restores the configured infrastructure hard denies; it does not bypass them.
Protected-path approvals are independent and stay open. Already-executing shell processes are not
terminated by a toggle.

`PI_AUTO_MODE=0` or `1` overrides `enabled` at startup; linked workers inherit the live parent setting.
While on, the statusbar shows `auto-mode` before the context percentage. Deterministic shell rules
still run first; `/no-safety` disables them, including rule-based asks, but does not disable the
classifier gate.

### Permission review

Interactive approvals use a centered `🛡 tool` heading and a separate syntax-highlighted code
block, with the rule reason kept outside the executable code. Short operations get a compact
card; operations over 600 characters or six lines get a nearly full-screen, read-only pager.
The complete command or file content remains available. Edits show every exact old/new replacement
as a diff, without reading or modifying the target file to construct the preview.

Long reviews generate a one-sentence summary of **at most 20 words**, using a separate low-effort
request to the active Pi model. Only the proposed operation is sent, not the conversation.
The summary is advisory: it never changes the verdict. Review is available immediately;
closing cancels summary generation, and a missing model, failure, or eight-second timeout leaves
the full operation available without a summary. Summary requests use the active model's
credentials and billing, not the selected Decisions backend.

- `a` allows; `d` or `Esc` denies, in both compact and long modes. Enter alone never approves.
- `j/k`, arrows, and `Ctrl-e/Ctrl-y` scroll one line; `Ctrl-d/u` scroll half a page.
- Page Up/Down scroll a page; `g/G` jump to the beginning/end.
- `/` opens literal case-insensitive search; Enter searches, `n/N` jump between matches.
  Escape leaves search first; typing `a` or `d` inside search cannot approve or deny.
- `w` toggles wrapping; `h/l` or left/right arrows pan unwrapped lines.
- Mouse-wheel events inside the panel scroll it. Regular terminal mode enables mouse capture
  only while the dialog is open (use Shift-drag for terminal text selection).
- The navigation legend stays hidden; approval controls remain visible, separated by a blank line.

Parallel local and worker approvals share one queue so only one owns the keyboard. Worker reviews
show the worker name and working directory alongside the complete operation. Cancellation or
shutdown closes the affected review; cancelled queued requests cannot reopen in a later turn.
RPC clients receive complete fenced code with Allow / Deny choices instead of a custom TUI.

Forwarding and shared toggles use explicit, lifetime-scoped parent identity in the same process,
not a global default terminal. The tracked pi-subagents runner patch scopes extension startup to
the actual spawning parent, including in-memory and nested workers, without forcing persistence.
Concurrent worker startups cannot exchange parents. Resumed workers use their current spawner,
not stale ancestry in a saved file. Without that patch, persisted `parentSession` ancestry remains
a compatibility fallback. Unlinked sessions and separate processes retain their local mode; asks
without their own UI or a live parent UI still block. No permission is inferred from missing UI.

Apply the runner patch after updating it, then restart Pi or run `/reload` so newly started workers
load the binding hook:

```sh
dotfiles/pi/.pi/agent/patches/apply.sh
```

Protected-file approvals show the matched path rule separately from the proposed write or edit.

After first adding the viewer or shared session-state module, restow the Pi package before `/reload`:

```sh
stow --verbose --no-folding --dir dotfiles --target "$HOME" --restow pi
```
