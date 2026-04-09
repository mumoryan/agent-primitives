#!/bin/bash
# guard-orchestrator.sh — PreToolUse hook for orchestrator agent only
# Restricts Bash to approved infrastructure scripts and read-only commands.
# Registered in the orchestrator's agent stub, not globally.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only restrict Bash tool — let Read, Write (to specs/), Agent pass through
if [ "$TOOL" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Allowlist: infrastructure scripts the orchestrator may invoke
ALLOWED_SCRIPTS="scripts/loci-dispatch\.sh|scripts/loci-start\.sh|scripts/loci-end\.sh|scripts/sync-events\.sh|scripts/dashboard\.sh"

# Allowlist: read-only commands for inspecting state
ALLOWED_READONLY="^(cat|ls|head|tail|wc|grep|find|git status|git branch|git log|git diff|git ls-remote) "

# Allowlist: source .agent-env (used in dispatch flow)
ALLOWED_SOURCE="^source \.agent-env"

if echo "$COMMAND" | grep -qE "(bash )?(\./)?(${ALLOWED_SCRIPTS})"; then
  exit 0  # approved script
elif echo "$COMMAND" | grep -qE "$ALLOWED_READONLY"; then
  exit 0  # read-only command
elif echo "$COMMAND" | grep -qE "$ALLOWED_SOURCE"; then
  exit 0  # sourcing agent env
else
  echo "Blocked: orchestrator bash restricted to approved scripts and read-only commands" >&2
  echo "Attempted: $COMMAND" >&2
  exit 2  # hard block
fi
