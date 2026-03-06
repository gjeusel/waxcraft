#!/usr/bin/env bash

# Read hook input from stdin and extract file_path
file_path=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$file_path" ]]; then
  exit 0
fi

extension=".${file_path##*.}"
extension="${extension,,}" # lowercase

sensitive_extensions=(.env .pem .key .credential .token)

for ext in "${sensitive_extensions[@]}"; do
  if [[ "$extension" == "$ext" ]]; then
    filename=$(basename "$file_path")
    echo "SECURITY_POLICY_VIOLATION: Access to the sensitive file '$filename' is blocked. Reason: Files with extensions like ${sensitive_extensions[*]} contain credentials and should not be accessed or modified by the AI. Please use environment variables or a secure secret management tool instead." >&2
    exit 2
  fi
done

exit 0
