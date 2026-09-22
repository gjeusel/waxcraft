#!/bin/sh
set -eu

agent_dir=${PI_CODING_AGENT_DIR:-"$HOME/.pi/agent"}
patch_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# A subshell keeps each package's paths and patch status separate.
apply_patch() (
  package_name=$1
  package_dir="$agent_dir/$2"
  patch_file="$patch_dir/$3"
  shift 3

  # Packages may be absent on a first-time Pi install. Apply after installation.
  if [ ! -d "$package_dir" ]; then
    echo "Skipping $package_name; not installed at $package_dir" >&2
    exit 0
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

apply_patch @tintinweb/pi-subagents npm/node_modules/@tintinweb/pi-subagents \
  pi-subagents-0.19.0-foreground-labels.patch src/agent-color.ts
apply_patch pi-black git/github.com/paoloanzn/pi-black \
  pi-black-cc2.1.280.patch src/claude-code-protocol.ts test/claude-code-protocol.test.ts
