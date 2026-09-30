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

# Pi warns about extension packages that list host-provided modules (TypeBox, Pi's own packages) in
# `dependencies`. Its loader aliases them to the host copies anyway, so moving them to "*"
# peerDependencies records what already happens at runtime. Upstream fixes make this a no-op.
declare_host_peers() {
  npm_dir="$agent_dir/npm"
  if [ ! -f "$npm_dir/package.json" ]; then
    echo "Skipping host peer declarations; no packages at $npm_dir" >&2
    return 0
  fi

  node -e '
const { existsSync, readFileSync, writeFileSync } = require("node:fs");
const { join } = require("node:path");

const hostPackages = new Set([
  "@earendil-works/pi-agent-core", "@earendil-works/pi-ai", "@earendil-works/pi-coding-agent",
  "@earendil-works/pi-tui", "@mariozechner/pi-agent-core", "@mariozechner/pi-ai",
  "@mariozechner/pi-coding-agent", "@mariozechner/pi-tui", "@sinclair/typebox", "typebox",
]);
const npmDir = process.argv[1];
const installed = Object.keys(JSON.parse(readFileSync(join(npmDir, "package.json"), "utf8")).dependencies ?? {});

for (const name of installed) {
  const manifestPath = join(npmDir, "node_modules", name, "package.json");
  if (!existsSync(manifestPath)) continue;

  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  const moved = Object.keys(manifest.dependencies ?? {}).filter((dep) => hostPackages.has(dep));
  if (moved.length === 0) continue;

  manifest.peerDependencies ??= {};
  for (const dep of moved) {
    delete manifest.dependencies[dep];
    manifest.peerDependencies[dep] = "*";
  }
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`Declared ${moved.join(", ")} as host peers of ${name}`);
}
' "$npm_dir"
}

declare_host_peers

apply_patch @tintinweb/pi-subagents npm/node_modules/@tintinweb/pi-subagents \
  pi-subagents-0.19.0-foreground-labels.patch src/agent-color.ts
apply_patch pi-black git/github.com/paoloanzn/pi-black \
  pi-black-cc2.1.280.patch src/claude-code-protocol.ts test/claude-code-protocol.test.ts
