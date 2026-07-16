#!/usr/bin/env bash

# PreToolUse hook (Bash): block python -c one-liners used to inspect modules.
# Hook input is JSON on stdin.
COMMAND=$(jq -r '.tool_input.command // empty' 2>/dev/null)

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

if echo "$COMMAND" | grep -qE 'python[23]?[[:space:]]+-c[[:space:]]+'; then
  if echo "$COMMAND" | grep -qE '__file__|__module__|__path__|__spec__'; then
    echo "BLOCKED: Do not use 'python -c' one-liners to inspect module locations." >&2
    echo "" >&2
    echo "Instead:" >&2
    echo "  1. Check ~/src/ for local source code" >&2
    echo "  2. Use 'uv pip show <pkg>' to find package info" >&2
    echo "  3. Use Grep/Glob tools to search codebases" >&2
    exit 2
  fi

  if echo "$COMMAND" | grep -qE '__version__'; then
    echo "BLOCKED: Do not use 'python -c' one-liners to check package versions." >&2
    echo "" >&2
    echo "Instead use: uv pip show <pkg>" >&2
    exit 2
  fi
fi

exit 0
