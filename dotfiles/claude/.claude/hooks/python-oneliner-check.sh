#!/usr/bin/env bash

COMMAND=$(jq -r '.tool_input.command // empty' <<< "$HOOK_INPUT")

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

if echo "$COMMAND" | grep -qE 'python[23]?\s+-c\s+' && \
   echo "$COMMAND" | grep -qE '__file__|__module__|__path__|__spec__'; then
  echo "BLOCKED: Do not use 'python -c' one-liners to inspect module locations." >&2
  echo "" >&2
  echo "Instead:" >&2
  echo "  1. Check ~/src/ for local source code" >&2
  echo "  2. Use 'uv pip show <pkg>' to find package info" >&2
  echo "  3. Use Grep/Glob tools to search codebases" >&2
  exit 2
fi

# Block python -c "import X; print(X.__version__)" patterns
if echo "$COMMAND" | grep -qE 'python[23]?\s+-c\s+' && \
   echo "$COMMAND" | grep -qE '__version__'; then
  echo "BLOCKED: Do not use 'python -c' one-liners to check package versions." >&2
  echo "" >&2
  echo "Instead use: uv pip freeze | grep <pkg>" >&2
  exit 2
fi

exit 0
