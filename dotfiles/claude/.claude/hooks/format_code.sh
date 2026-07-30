#!/usr/bin/env bash

# PostToolUse hook (Edit|Write): auto-format the edited file.
# Hook input is JSON on stdin.
file_path=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$file_path" || ! -f "$file_path" ]]; then
  exit 0
fi

extension="${file_path##*.}"

case ".$extension" in
  .py)
    # ruff may not be installed globally; fall back to uvx
    if command -v ruff >/dev/null 2>&1; then
      RUFF=(ruff)
    elif command -v uvx >/dev/null 2>&1; then
      RUFF=(uvx ruff)
    else
      exit 0
    fi
    # Ignore rules whose autofix would surprise an LLM mid-write (e.g. removing
    # not-yet-used variables/imports): unused vars, unused imports, etc.
    "${RUFF[@]}" check --fix --ignore "E203,F841,F401,RUF100,B007,PERF102" "$file_path" >/dev/null 2>&1 && echo "ruff check --fix $file_path"
    "${RUFF[@]}" format "$file_path" >/dev/null 2>&1 && echo "ruff format $file_path"
    ;;
  .rs)
    rustfmt "$file_path" 2>/dev/null && echo "rustfmt $file_path"
    ;;
  .go)
    gofmt -w "$file_path" 2>/dev/null && echo "gofmt $file_path"
    ;;
  .js|.ts|.jsx|.tsx|.vue)
    # Walk up to find the project root (nearest package.json)
    project_root=""
    dir=$(dirname "$file_path")
    while [[ "$dir" != "/" ]]; do
      if [[ -f "$dir/package.json" ]]; then
        project_root="$dir"
        break
      fi
      dir=$(dirname "$dir")
    done

    has_dep() {
      jq -e --arg d "$1" '.devDependencies[$d] // .dependencies[$d]' "$project_root/package.json" >/dev/null 2>&1
    }

    if [[ -n "$project_root" ]]; then
      if has_dep oxfmt; then
        oxfmt "$file_path" >/dev/null 2>&1 && echo "oxfmt $file_path"
      elif has_dep prettier; then
        prettier --write "$file_path" >/dev/null 2>&1 && echo "prettier --write $file_path"
      fi

      if has_dep oxlint; then
        oxlint --fix "$file_path" >/dev/null 2>&1 && echo "oxlint --fix $file_path"
      elif has_dep eslint; then
        eslint --fix "$file_path" >/dev/null 2>&1 && echo "eslint --fix $file_path"
      fi
    fi
    ;;
esac

exit 0
