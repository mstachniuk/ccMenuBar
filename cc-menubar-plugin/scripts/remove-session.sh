#!/bin/bash
# Reads hook event JSON from stdin, removes session status file

set -euo pipefail

STATUS_DIR="$HOME/.claude/ccMenuBar/sessions"

# Read JSON from stdin
INPUT=$(cat)

# Extract session_id
SESSION_ID=$(echo "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

if [ -z "$SESSION_ID" ]; then
  exit 0
fi

rm -f "${STATUS_DIR}/${SESSION_ID}.json"
