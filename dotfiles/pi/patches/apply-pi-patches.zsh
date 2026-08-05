#!/bin/zsh

# Keep the FFF fix reproducible without committing changes under ~/.pi/agent/npm.
# Pi installs packages into that directory and may replace them during updates.

setopt no_unset

npm_root="$HOME/.pi/agent/npm"
package_file="$npm_root/node_modules/@ff-labs/pi-fff/src/aux-finders.ts"
patch_file="${WAXPATH:-$HOME/src/waxcraft}/dotfiles/pi/patches/@ff-labs+pi-fff+0.10.1.patch"

[[ -f "$package_file" && -f "$patch_file" ]] || exit 0

# Make repeated Pi launches and updates idempotent.
if grep -Fq 'function findGitRoot' "$package_file"; then
  exit 0
fi

if ! patch -N -s -p1 -d "$npm_root" < "$patch_file"; then
  print -u2 "warning: could not apply the pi-fff patch; check the installed pi-fff version"
  exit 1
fi
