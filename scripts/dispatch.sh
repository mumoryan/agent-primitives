#!/bin/bash
# dispatch.sh — prepare worktree for agent instance
# Usage: dispatch.sh <project-dir> <agent-name> <instance-number> <spec-category> <spec-name>
# Example: dispatch.sh ~/Dev/loci frontend-implementer 1 features entry-sequence
#
# Creates: <project-dir>/worktrees/<agent-name>-<instance>/
# The supervisor calls this before dispatching a subagent.

set -e

PROJECT_DIR="${1:?Usage: dispatch.sh <project-dir> <agent> <instance> <category> <spec>}"
AGENT="${2:?Missing agent name}"
INSTANCE="${3:?Missing instance number}"
CATEGORY="${4:?Missing spec category}"
SPEC="${5:?Missing spec name}"

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

BRANCH="${AGENT}-${INSTANCE}/${CATEGORY}/${SPEC}"
WORKTREE_DIR="$PROJECT_DIR/worktrees/${AGENT}-${INSTANCE}"

echo "=== Dispatch: $AGENT instance $INSTANCE ==="
echo "Branch: $BRANCH"
echo "Worktree: $WORKTREE_DIR"

# --- Check instance limit ---

ACTIVE=$(find "$PROJECT_DIR/worktrees" -maxdepth 1 -type d 2>/dev/null | grep -c "$AGENT" || echo "0")
MAX_INSTANCES=5

if [ "$ACTIVE" -ge "$MAX_INSTANCES" ]; then
  echo "FAIL: $AGENT already has $ACTIVE active instances (max: $MAX_INSTANCES)"
  exit 1
fi

# --- Clean up stale worktree if exists ---

if [ -d "$WORKTREE_DIR" ]; then
  echo "Cleaning up stale worktree..."
  git -C "$PROJECT_DIR" worktree remove "$WORKTREE_DIR" --force 2>/dev/null || true
fi

# --- Create worktree ---

echo "Creating worktree..."
cd "$PROJECT_DIR"

# Create branch from current main
git worktree add "$WORKTREE_DIR" -b "$BRANCH" main

# --- Set up sparse checkout per agent type ---
# Each agent only sees the directories it needs.
# scripts/ is excluded from all agents — only supervisor (main checkout) can see them.

cd "$WORKTREE_DIR"
git sparse-checkout init --cone 2>/dev/null || true

case "$AGENT" in
  frontend-implementer)
    git sparse-checkout set frontend specs .claude ARCHITECTURE.md logs
    ;;
  backend-implementer)
    git sparse-checkout set backend specs .claude ARCHITECTURE.md logs
    ;;
  world-builder)
    git sparse-checkout set frontend/src/worlds specs .claude ARCHITECTURE.md
    ;;
  *)
    # Fallback: conservative set, no scripts
    git sparse-checkout set frontend backend specs .claude ARCHITECTURE.md logs
    ;;
esac

echo "Sparse checkout configured for $AGENT"
echo "Excluded from worktree: scripts/, loci-docs/, worktrees/"

# --- Export env vars for the agent ---

ENV_FILE="$WORKTREE_DIR/.agent-env"
cat > "$ENV_FILE" << EOF
export LOCI_AGENT="$AGENT"
export LOCI_INSTANCE="$INSTANCE"
export LOCI_BRANCH="$BRANCH"
export LOCI_SPEC_CATEGORY="$CATEGORY"
export LOCI_SPEC_NAME="$SPEC"
export LOCI_SESSION_ID="${LOCI_SESSION_ID:-ses_$(date +%s)}"
export LOCI_TRACE_ID="${LOCI_TRACE_ID:-trc_unknown}"
EOF

echo ""
echo "=== Worktree ready ==="
echo "Agent env written to: $ENV_FILE"
echo "Supervisor: dispatch subagent to work in $WORKTREE_DIR"
echo "Agent should: source .agent-env, then implement spec"
echo ""
