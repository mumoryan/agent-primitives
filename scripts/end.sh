#!/bin/bash
# end.sh — session teardown and archiving
# Usage: end.sh <project-dir>
# Run after Claude Code session ends.

set -e

PROJECT_DIR="${1:?Usage: end.sh <project-dir>}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

echo "=== Session teardown ==="

# --- Sync events to observability DB ---

echo "Syncing events..."
SYNC_SCRIPT="$PROJECT_DIR/../agent-primitives/observability/sync-events.sh"
if [ -x "$SYNC_SCRIPT" ]; then
  "$SYNC_SCRIPT" "$PROJECT_DIR"
else
  echo "WARN: sync-events.sh not found or not executable, skipping"
fi

# --- Clean up merged worktrees ---

echo "Cleaning up worktrees..."
if [ -d "$PROJECT_DIR/worktrees" ]; then
  for wt in "$PROJECT_DIR/worktrees"/*/; do
    [ -d "$wt" ] || continue
    WT_NAME=$(basename "$wt")

    # Check if the branch has been merged
    BRANCH=$(git -C "$wt" branch --show-current 2>/dev/null || echo "")
    if [ -n "$BRANCH" ]; then
      MERGED=$(git -C "$PROJECT_DIR" branch --merged main | grep -c "$BRANCH" || echo "0")
      if [ "$MERGED" -gt "0" ]; then
        echo "  Removing merged worktree: $WT_NAME"
        git -C "$PROJECT_DIR" worktree remove "$wt" --force 2>/dev/null || true
      else
        echo "  Keeping unmerged worktree: $WT_NAME (branch: $BRANCH)"
      fi
    fi
  done
fi

# --- Archive session log ---

echo "Archiving session..."
SESSION_ID="${LOCI_SESSION_ID:-unknown}"
ARCHIVE_DIR="$PROJECT_DIR/logs/archive"
mkdir -p "$ARCHIVE_DIR"

# Copy current progress.md as session snapshot
cp "$PROJECT_DIR/logs/progress.md" "$ARCHIVE_DIR/progress_${SESSION_ID}.md" 2>/dev/null || true

# --- Summary ---

EVENT_COUNT=$(wc -l < "$PROJECT_DIR/logs/events.jsonl" 2>/dev/null | tr -d ' ' || echo "0")
WORKTREE_COUNT=$(find "$PROJECT_DIR/worktrees" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ' || echo "0")
# Subtract 1 for the worktrees directory itself
WORKTREE_COUNT=$((WORKTREE_COUNT > 0 ? WORKTREE_COUNT - 1 : 0))

echo ""
echo "=== Session teardown complete ==="
echo "Events logged: $EVENT_COUNT"
echo "Remaining worktrees: $WORKTREE_COUNT"
echo ""
echo "To view dashboard: ./scripts/dashboard.sh"
echo ""
