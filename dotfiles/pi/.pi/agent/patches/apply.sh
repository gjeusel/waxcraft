#!/bin/sh
set -eu

agent_dir=${PI_CODING_AGENT_DIR:-"$HOME/.pi/agent"}
patch_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# A subshell keeps each package's paths and patch status separate.
apply_patch() (
  package_name=$1
  package_dir="$agent_dir/npm/node_modules/$package_name"
  patch_file="$patch_dir/$2"
  shift 2

  if [ ! -d "$package_dir" ]; then
    echo "$package_name is not installed at $package_dir" >&2
    exit 1
  fi

  patch_changed=false
  for relative_path in "$@"; do
    if git -C "$package_dir" apply --check --include="$relative_path" "$patch_file" 2>/dev/null; then
      git -C "$package_dir" apply --include="$relative_path" "$patch_file"
      patch_changed=true
    elif ! git -C "$package_dir" apply --reverse --check --include="$relative_path" "$patch_file" 2>/dev/null; then
      echo "Cannot patch $relative_path; $package_name may have changed" >&2
      exit 1
    fi
  done

  if [ "$patch_changed" = true ]; then
    echo "Applied $(basename "$patch_file")"
  else
    echo "Already applied $(basename "$patch_file")"
  fi
)

apply_patch pi-claude-bridge pi-claude-bridge-0.7.0-fable-5-1.patch package.json src/models.ts
apply_patch @tintinweb/pi-subagents pi-subagents-0.19.0-foreground-labels.patch src/agent-color.ts

package_dir="$agent_dir/npm/node_modules/pi-claude-bridge"
sdk_package="$package_dir/node_modules/@anthropic-ai/claude-agent-sdk/package.json"
sdk_version=
if [ -f "$sdk_package" ]; then
  sdk_version=$(node -p "require(process.argv[1]).version" "$sdk_package")
fi

if [ "$sdk_version" != "0.3.251" ]; then
  npm install --prefix "$package_dir" --omit=dev --ignore-scripts --no-package-lock --no-audit --no-fund
fi
