#!/usr/bin/env bash

# Dual-purpose secrets guard. Hook input is JSON on stdin.
# - PreToolUse (Read|Edit|Write): block access to credential-bearing files.
# - UserPromptSubmit: scan the prompt text with gitleaks; block if a secret is found.
input=$(cat)
event=$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null)

if [[ "$event" == "UserPromptSubmit" ]]; then
  # Fail-open if gitleaks is missing — the guard must never brick the session.
  command -v gitleaks >/dev/null || exit 0
  findings=$(jq -r '.prompt // empty' <<<"$input" |
    gitleaks stdin --no-banner --no-color --redact -v 2>/dev/null)
  if [[ $? -eq 1 && -n "$findings" ]]; then
    echo "SECURITY_POLICY_VIOLATION: prompt blocked — gitleaks detected secret(s):" >&2
    echo "$findings" >&2
    exit 2
  fi
  exit 0
fi

file_path=$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null)

if [[ -z "$file_path" ]]; then
  exit 0
fi

filename=$(basename "$file_path" | tr '[:upper:]' '[:lower:]')

# Match on basename so multi-suffix names like .env.production are caught.
case "$filename" in
  .env|.env.*|*.pem|*.key|*.credential|*.credentials|*.token|id_rsa|id_rsa.*|id_ed25519|id_ed25519.*)
    echo "SECURITY_POLICY_VIOLATION: Access to the sensitive file '$filename' is blocked. Reason: this file likely contains credentials and must not be read or modified by the AI. Use environment variables or a secure secret management tool instead." >&2
    exit 2
    ;;
esac

exit 0
