#!/usr/bin/env bash

# PreToolUse hook (Read|Edit|Write): block access to credential-bearing files.
# Hook input is JSON on stdin.
file_path=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)

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
