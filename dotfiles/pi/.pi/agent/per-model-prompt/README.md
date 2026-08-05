# per-model-prompt

Per-model system-prompt additions, loaded by `extensions/per-model-prompt.ts`.

On each turn, if `<model-id>.md` exists here it is appended to the system
prompt. Model ids containing `/` map to files with `--` instead
(e.g. `qwen/qwen3-coder` → `qwen--qwen3-coder.md`).

Examples: `gpt-5.6-luna.md`, `claude-fable-5.md`, `kimi-k3.md`.

Empty or whitespace-only files are ignored. Re-run stow after adding a file so
it gets symlinked into `~/.pi/agent/per-model-prompt/`.
