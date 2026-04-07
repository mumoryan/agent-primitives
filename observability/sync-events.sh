#!/bin/bash
# Syncs logs/events.jsonl into logs/observability.db (SQLite)
# Reusable across projects — pass project root as argument.
# Run: at end of each supervisor session + on demand by human
# Usage: ./sync-events.sh <project-dir>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:?Usage: sync-events.sh <project-dir>}"
DB_PATH="$PROJECT_DIR/logs/observability.db"
EVENTS_PATH="$PROJECT_DIR/logs/events.jsonl"
SCHEMA_PATH="$SCRIPT_DIR/schema.sql"

# Initialize DB if it doesn't exist
if [ ! -f "$DB_PATH" ]; then
  echo "Initializing database..."
  sqlite3 "$DB_PATH" < "$SCHEMA_PATH"
fi

# Check events file exists and is non-empty
if [ ! -s "$EVENTS_PATH" ]; then
  echo "No events to sync."
  exit 0
fi

# Count existing events to determine what's new
EXISTING=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM events;" 2>/dev/null || echo "0")
TOTAL=$(wc -l < "$EVENTS_PATH" | tr -d ' ')

if [ "$EXISTING" -ge "$TOTAL" ]; then
  echo "Database is up to date ($EXISTING events)."
  exit 0
fi

# Skip already-synced lines, import new ones
SKIP=$EXISTING
echo "Syncing $((TOTAL - SKIP)) new events..."

tail -n "+$((SKIP + 1))" "$EVENTS_PATH" | while IFS= read -r line; do
  # Extract fields from JSON line using jq
  sqlite3 "$DB_PATH" "INSERT OR IGNORE INTO events (
    id, session_id, trace_id, agent, model, event_type, tool, tool_type,
    ts, duration_ms, tokens_input, tokens_output, tokens_cache_read,
    tokens_cache_write, cost_usd, cost_bucket, input_summary, output_summary,
    sensitive_data, review_required, retry_count, error
  ) VALUES (
    $(echo "$line" | jq -r '[
      .event_id, .session_id, .trace_id, .agent, .model, .event_type,
      .tool, .tool_type, .ts, .duration_ms,
      (.tokens.input // 0), (.tokens.output // 0),
      (.tokens.cache_read // 0), (.tokens.cache_write // 0),
      (.cost_usd // 0), .cost_bucket, .input_summary, .output_summary,
      (.sensitive_data // false), (.review_required // false),
      (.retry_count // 0), .error
    ] | map(if . == null then "NULL" elif type == "boolean" then (if . then 1 else 0 end) elif type == "number" then . else @json end) | join(",")')
  );"
done

# Update trace summaries
sqlite3 "$DB_PATH" "
  INSERT OR REPLACE INTO traces (trace_id, spec_path, spec_category, status, started_at, completed_at, total_cost_usd, total_events, retry_total)
  SELECT
    trace_id,
    COALESCE(input_summary, ''),
    '',
    CASE WHEN SUM(CASE WHEN error IS NOT NULL THEN 1 ELSE 0 END) > 0 THEN 'blocked' ELSE 'complete' END,
    MIN(ts),
    MAX(ts),
    SUM(cost_usd),
    COUNT(*),
    SUM(retry_count)
  FROM events
  WHERE trace_id IS NOT NULL
  GROUP BY trace_id;
"

# Update agent stats for today
sqlite3 "$DB_PATH" "
  INSERT OR REPLACE INTO agent_stats (agent, period, total_events, total_cost_usd, avg_duration_ms, retry_count)
  SELECT
    agent,
    DATE(ts),
    COUNT(*),
    SUM(cost_usd),
    AVG(duration_ms),
    SUM(retry_count)
  FROM events
  WHERE DATE(ts) = DATE('now')
  GROUP BY agent;
"

FINAL=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM events;")
echo "Sync complete. $FINAL total events in database."
