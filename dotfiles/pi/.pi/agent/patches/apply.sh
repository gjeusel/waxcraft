#!/bin/sh
set -eu

agent_dir=${PI_CODING_AGENT_DIR:-"$HOME/.pi/agent"}
package_dir="$agent_dir/npm/node_modules/pi-claude-bridge"
patch_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
patch_file="$patch_dir/pi-claude-bridge-0.7.0-fable-5-1.patch"

if [ ! -d "$package_dir" ]; then
  echo "pi-claude-bridge is not installed at $package_dir" >&2
  exit 1
fi

patch_changed=false
for relative_path in package.json src/models.ts; do
  if git -C "$package_dir" apply --check --include="$relative_path" "$patch_file" 2>/dev/null; then
    git -C "$package_dir" apply --include="$relative_path" "$patch_file"
    patch_changed=true
  elif ! git -C "$package_dir" apply --reverse --check --include="$relative_path" "$patch_file" 2>/dev/null; then
    echo "Cannot patch $relative_path; pi-claude-bridge may have changed" >&2
    exit 1
  fi
done

if [ "$patch_changed" = true ]; then
  echo "Applied $(basename "$patch_file")"
else
  echo "Already applied $(basename "$patch_file")"
fi

sdk_package="$package_dir/node_modules/@anthropic-ai/claude-agent-sdk/package.json"
sdk_version=
if [ -f "$sdk_package" ]; then
  sdk_version=$(node -p "require(process.argv[1]).version" "$sdk_package")
fi

if [ "$sdk_version" != "0.3.251" ]; then
  npm install --prefix "$package_dir" --omit=dev --ignore-scripts --no-package-lock --no-audit --no-fund
fi
