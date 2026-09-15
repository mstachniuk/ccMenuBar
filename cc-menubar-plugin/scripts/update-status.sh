#!/bin/bash
# Reads hook event JSON from stdin, writes session status to ~/.claude/ccMenuBar/sessions/

set -euo pipefail

STATUS_DIR="$HOME/.claude/ccMenuBar/sessions"
mkdir -p "$STATUS_DIR"

# Read JSON from stdin
INPUT=$(cat)

# Extract fields using built-in tools (no jq dependency)
extract_json_string() {
  echo "$INPUT" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

SESSION_ID=$(extract_json_string "session_id")
CWD=$(extract_json_string "cwd")
HOOK_EVENT=$(extract_json_string "hook_event_name")
TOOL_NAME=$(extract_json_string "tool_name")
PARENT_SESSION_ID=$(extract_json_string "parent_session_id")

if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# Determine status based on hook event
case "$HOOK_EVENT" in
  PreToolUse|PostToolUse)
    STATUS="busy"
    ;;
  SessionStart)
    STATUS="active"
    ;;
  Stop|Notification)
    STATUS="idle"
    ;;
  *)
    STATUS="active"
    ;;
esac

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Write status file atomically
TMPFILE="${STATUS_DIR}/.${SESSION_ID}.tmp"
cat > "$TMPFILE" <<EOF
{
  "session_id": "${SESSION_ID}",
  "status": "${STATUS}",
  "cwd": "${CWD}",
  "last_event": "${HOOK_EVENT}",
  "tool_name": "${TOOL_NAME}",
  "parent_session_id": "${PARENT_SESSION_ID}",
  "timestamp": "${TIMESTAMP}"
}
EOF

mv "$TMPFILE" "${STATUS_DIR}/${SESSION_ID}.json"
