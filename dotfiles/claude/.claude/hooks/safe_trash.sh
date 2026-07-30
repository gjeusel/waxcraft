#!/bin/bash
# PreToolUse hook: block `trash` on sensitive paths.
# Exit 2 blocks the Bash call and feeds stderr back to Claude.
# Fails closed: trash commands too complex to parse safely are blocked.

set -u

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
[[ "$cmd" != *trash* ]] && exit 0
cwd=$(jq -r '.cwd // ""' <<<"$input")
[[ -z "$cwd" ]] && cwd=$PWD

block() {
  echo "safe_trash: $1" >&2
  exit 2
}

# Temp locations exempt from every restriction.
SAFE_PREFIXES=(/tmp /private/tmp /var/tmp /private/var/tmp /var/folders /private/var/folders)
# Absolute prefixes where nothing may ever be trashed.
SYSTEM_PREFIXES=(/System /Library /Applications /usr /bin /sbin /etc /private/etc /opt /nix /Volumes)
# Dot-directories under $HOME protected at any depth.
HOME_PROTECTED=(.ssh .gnupg .aws .kube .config .claude)

is_under() { [[ "$1" == "$2" || "$1" == "$2"/* ]]; }

# Judge one normalized absolute path; blocks (exits) if sensitive.
judge() {
  local p=$1 prefix name rel
  for prefix in "${SAFE_PREFIXES[@]}"; do
    is_under "$p" "$prefix" && return 0
  done
  [[ "$p" == / ]] && block "refusing to trash /"
  [[ "$p" == /*/* ]] || block "refusing to trash top-level directory $p"
  for prefix in "${SYSTEM_PREFIXES[@]}"; do
    is_under "$p" "$prefix" && block "refusing to trash system path $p"
  done
  [[ "$p" == "$HOME" ]] && block "refusing to trash the home directory"
  if is_under "$p" "$HOME"; then
    rel=${p#"$HOME"/}
    [[ "$rel" == */* ]] || block "refusing to trash top-level home directory ~/$rel"
    for name in "${HOME_PROTECTED[@]}"; do
      is_under "$rel" "$name" && block "refusing to trash path under protected ~/$name"
    done
  fi
  return 0
}

check_arg() {
  local raw=$1 p=$1 resolved

  # Expand ~ and $HOME; anything else dynamic is blocked (fail closed).
  [[ "$p" == "~" || "$p" == "~/"* ]] && p="$HOME${p#\~}"
  [[ "$p" == '$HOME' || "$p" == '$HOME/'* ]] && p="$HOME${p#\$HOME}"
  [[ "$p" == *'$'* ]] && block "cannot resolve shell variable in '$raw'; use a literal path"
  # `cd` earlier in the command would change what `..` resolves against.
  [[ "/$p/" == *"/../"* ]] && block "refusing '..' path traversal in '$raw'; use an absolute path"

  # For globs, validate the deepest concrete parent directory instead.
  if [[ "$p" == *[\*\?\[]* ]]; then
    p=${p%%[\*\?\[]*}
    [[ "$p" == */ ]] || p=$(dirname "$p")
  fi

  [[ "$p" != /* ]] && p="$cwd/$p"
  # Lexical normalization ('..' already rejected above).
  while [[ "$p" == *"//"* ]]; do p=${p//\/\///}; done
  while [[ "$p" == *"/./"* ]]; do p=${p//\/.\///}; done
  [[ "$p" == */. ]] && p=${p%/.}
  [[ "$p" != / ]] && p=${p%/}

  # Judge the lexical path, then the symlink-resolved one: stow symlinks
  # (e.g. ~/.config/nvim -> ~/src/waxcraft/...) would otherwise let the
  # resolved path escape a protected directory.
  judge "$p"
  resolved=$(realpath "$p" 2>/dev/null) && judge "$resolved"
}

# Split compound commands on shell separators, keep segments led by trash.
segments=$(sed -E 's/&&|\|\||[;|&]/\n/g' <<<"$cmd")
while IFS= read -r seg; do
  read -r -a words <<<"$seg"
  [[ ${#words[@]} -eq 0 ]] && continue
  first=${words[0]}
  [[ "$first" == trash || "$first" == */trash ]] || continue
  # Quoting/escaping defeats naive word splitting — fail closed.
  [[ "$seg" == *[\'\"\\]* ]] && block "quotes or escapes in a trash command; use simple unquoted paths"
  for word in "${words[@]:1}"; do
    [[ "$word" == -* ]] && continue
    check_arg "$word"
  done
done <<<"$segments"

exit 0
