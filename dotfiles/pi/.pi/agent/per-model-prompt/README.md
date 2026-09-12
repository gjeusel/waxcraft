# per-model-prompt

Per-model system-prompt additions, loaded by `extensions/per-model-prompt/index.ts`.

On each turn, if `<model-id>.md` exists here it is appended to the system
prompt. Model ids containing `/` map to files with `--` instead
(e.g. `qwen/qwen3-coder` → `qwen--qwen3-coder.md`).

Examples: `gpt-5.6-luna.md`, `claude-fable-5.md`, `kimi-k3.md`.

Empty or whitespace-only files are ignored. Re-run stow after adding a file so
it gets symlinked into `~/.pi/agent/per-model-prompt/`.

Keep directives specific to observed behavior of that model. Shared preferences belong in
`APPEND_SYSTEM.md`; workflow details belong in skills. When adding feedback with `/mfb`, review the
file for duplicates or superseded guidance rather than accumulating a new rule for every failure.
