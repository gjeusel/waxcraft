#!/usr/bin/env bash

FILE_PATH=$(jq -r '.tool_input.file_path // .tool_input.filePath // empty' <<< "$HOOK_INPUT")

# Only check Python test files
if [[ -z "$FILE_PATH" || ! "$FILE_PATH" =~ \.py$ ]]; then
  exit 0
fi

basename=$(basename "$FILE_PATH")
if [[ ! "$basename" =~ ^test_.*\.py$|_test\.py$ ]]; then
  exit 0
fi

VIOLATIONS=$(grep -n '^[[:space:]]\+\(import \|from .* import \)' "$FILE_PATH" 2>/dev/null || true)

if [[ -n "$VIOLATIONS" ]]; then
  echo "Dynamic imports detected in test file $FILE_PATH:" >&2
  echo "$VIOLATIONS" >&2
  echo "" >&2
  echo "Move these imports to module level (top of file)." >&2
  exit 2
fi

exit 0
