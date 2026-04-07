#!/usr/bin/env bash

# Only format if the file was actually modified by Write, Edit, or MultiEdit tools
case "$CLAUDE_TOOL_NAME" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

file_path=$(echo "$CLAUDE_TOOL_ARGS" | jq -r '.file_path // empty')

if [[ -z "$file_path" || ! -f "$file_path" ]]; then
  exit 0
fi

extension="${file_path##*.}"

case ".$extension" in
  .py)
    ruff check --fix "$file_path" 2>/dev/null && echo "ruff check --fix $file_path"
    ruff format "$file_path" 2>/dev/null && echo "ruff format $file_path"
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

    use_oxfmt=false
    use_oxlint=false
    if [[ -n "$project_root" ]]; then
      if jq -e '.devDependencies.oxfmt // .dependencies.oxfmt' "$project_root/package.json" >/dev/null 2>&1; then
        use_oxfmt=true
      fi
      if jq -e '.devDependencies.oxlint // .dependencies.oxlint' "$project_root/package.json" >/dev/null 2>&1; then
        use_oxlint=true
      fi
    fi

    if $use_oxfmt; then
      oxfmt "$file_path" 2>/dev/null && echo "oxfmt $file_path"
    elif prettier --write "$file_path" 2>/dev/null; then
      echo "prettier --write $file_path"
    fi

    if $use_oxlint; then
      oxlint --fix "$file_path" 2>/dev/null && echo "oxlint --fix $file_path"
    elif eslint --fix "$file_path" 2>/dev/null; then
      echo "eslint --fix $file_path"
    fi
    ;;
esac

exit 0
