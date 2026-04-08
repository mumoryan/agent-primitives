#!/bin/bash
# start.sh — deterministic session bootstrap
# Usage: start.sh <project-dir>
# Run this instead of `claude` directly. Nothing starts until all checks pass.

set -e

PROJECT_DIR="${1:?Usage: start.sh <project-dir>}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

echo "=== Session bootstrap ==="
echo "Project: $PROJECT_DIR"

# --- Prerequisites ---

echo "Checking prerequisites..."
command -v jq >/dev/null || { echo "FAIL: jq not installed"; exit 1; }
command -v bun >/dev/null || { echo "FAIL: bun not installed"; exit 1; }
command -v git >/dev/null || { echo "FAIL: git not installed"; exit 1; }
command -v claude >/dev/null || { echo "FAIL: claude CLI not installed"; exit 1; }

# --- Scripts executable ---

echo "Ensuring scripts are executable..."
chmod +x "$PROJECT_DIR/scripts/"*.sh 2>/dev/null || true

# --- Required files ---

echo "Checking required files..."
for f in \
  ".claude/CLAUDE.md" \
  "ARCHITECTURE.md" \
  "scripts/guard-core.sh" \
  "scripts/log-event.sh" \
  "logs/progress.md"
do
  [ -f "$PROJECT_DIR/$f" ] || { echo "FAIL: missing $f"; exit 1; }
done

# --- Hooks registered ---

echo "Checking hooks..."
HOOKS=$(jq '.hooks.PostToolUse // empty' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null)
[ -z "$HOOKS" ] && { echo "FAIL: PostToolUse hook not registered in settings.json"; exit 1; }

# --- Git state ---

echo "Checking git state..."
cd "$PROJECT_DIR"
git diff --quiet || { echo "FAIL: uncommitted changes — clean up before starting"; exit 1; }
git diff --cached --quiet || { echo "FAIL: staged changes — commit or reset before starting"; exit 1; }

# --- Generate session/trace IDs ---

export LOCI_SESSION_ID="ses_$(date +%s)"
export LOCI_TRACE_ID="trc_$(git rev-parse --short HEAD)_$(date +%s)"

echo ""
echo "Session ID: $LOCI_SESSION_ID"
echo "Trace ID:   $LOCI_TRACE_ID"

# --- Hook verification (dry run) ---

echo "Verifying hooks fire..."
echo '{"tool_name":"_preflight_check","tool_input":{}}' \
  | "$PROJECT_DIR/scripts/log-event.sh"

if [ -f "$PROJECT_DIR/logs/events.jsonl" ]; then
  LAST_TOOL=$(tail -1 "$PROJECT_DIR/logs/events.jsonl" | jq -r '.tool // ""')
  if [ "$LAST_TOOL" = "_preflight_check" ] || [ -n "$LAST_TOOL" ]; then
    echo "Hook verification: OK"
  else
    echo "WARN: Hook fired but tool field unexpected: $LAST_TOOL"
  fi
else
  echo "WARN: events.jsonl not created — hook may not be writing"
fi

# --- Update progress.md ---

echo "Updating progress.md..."
cat > "$PROJECT_DIR/logs/progress.md.header" << EOF
_Session: $LOCI_SESSION_ID | Trace: $LOCI_TRACE_ID | Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)_

EOF
# Prepend header, keep existing content
cat "$PROJECT_DIR/logs/progress.md.header" "$PROJECT_DIR/logs/progress.md" \
  > "$PROJECT_DIR/logs/progress.md.tmp" \
  && mv "$PROJECT_DIR/logs/progress.md.tmp" "$PROJECT_DIR/logs/progress.md"
rm -f "$PROJECT_DIR/logs/progress.md.header"

# --- Launch Claude ---

echo ""
echo "=== All checks passed. Launching Claude Code ==="
echo "Environment variables exported: LOCI_SESSION_ID, LOCI_TRACE_ID"
echo ""

cd "$PROJECT_DIR"
exec claude
