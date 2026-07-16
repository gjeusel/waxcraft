#!/usr/bin/env bash

# PostToolUse hook (Edit|Write): flag imports inside test functions.
# Hook input is JSON on stdin.
FILE_PATH=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only check Python test files
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

filename=$(basename "$FILE_PATH")
if ! echo "$filename" | grep -qE '^(test_.*|.*_test)\.py$'; then
  exit 0
fi

# Flag indented imports, skipping known-legitimate blocks
# (if TYPE_CHECKING: and try/except ImportError guards).
VIOLATIONS=$(awk '
  /^if TYPE_CHECKING:/ || /^try:/ { guard = 1 }
  /^[^[:space:]]/ && !/^if TYPE_CHECKING:/ && !/^try:/ { guard = 0 }
  !guard && /^[[:space:]]+(import |from [^[:space:]]+ import )/ { print NR": "$0 }
' "$FILE_PATH")

if [[ -n "$VIOLATIONS" ]]; then
  echo "Dynamic imports detected in test file $FILE_PATH:" >&2
  echo "$VIOLATIONS" >&2
  echo "" >&2
  echo "Move these imports to module level (top of file)." >&2
  exit 2
fi

exit 0
