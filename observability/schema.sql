-- Observability database schema
-- Synced from logs/events.jsonl via sync-events.sh
-- Agents: read + append only. Never update or delete.

CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,                    -- event_id from jsonl
  session_id TEXT NOT NULL,
  trace_id TEXT,                          -- spans full feature implementation
  agent TEXT NOT NULL,
  model TEXT NOT NULL,
  event_type TEXT NOT NULL,
  tool TEXT NOT NULL,
  tool_type TEXT NOT NULL,                -- raw | mcp
  ts TEXT NOT NULL,                       -- ISO8601 UTC
  duration_ms INTEGER,
  tokens_input INTEGER DEFAULT 0,
  tokens_output INTEGER DEFAULT 0,
  tokens_cache_read INTEGER DEFAULT 0,
  tokens_cache_write INTEGER DEFAULT 0,
  cost_usd REAL DEFAULT 0,
  cost_bucket TEXT NOT NULL,              -- code_generation | world_building | review | orchestration
  input_summary TEXT,
  output_summary TEXT,
  sensitive_data BOOLEAN DEFAULT FALSE,
  review_required BOOLEAN DEFAULT FALSE,
  retry_count INTEGER DEFAULT 0,
  error TEXT
);

CREATE TABLE IF NOT EXISTS traces (
  trace_id TEXT PRIMARY KEY,
  spec_path TEXT NOT NULL,
  spec_category TEXT,                     -- features | refactors | optimizations | architecture
  status TEXT NOT NULL,                   -- in_progress | complete | blocked | escalated
  started_at TEXT NOT NULL,
  completed_at TEXT,
  total_cost_usd REAL DEFAULT 0,
  total_events INTEGER DEFAULT 0,
  agents_used TEXT,                       -- JSON array of agent names
  retry_total INTEGER DEFAULT 0,
  human_escalated BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS agent_stats (
  agent TEXT NOT NULL,
  period TEXT NOT NULL,                   -- YYYY-MM-DD or YYYY-WXX
  total_events INTEGER DEFAULT 0,
  total_cost_usd REAL DEFAULT 0,
  avg_duration_ms REAL DEFAULT 0,
  retry_count INTEGER DEFAULT 0,
  first_pass_rate REAL DEFAULT 0,         -- % of specs passed reviewer on first try
  PRIMARY KEY (agent, period)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_events_session ON events(session_id);
CREATE INDEX IF NOT EXISTS idx_events_trace ON events(trace_id);
CREATE INDEX IF NOT EXISTS idx_events_agent ON events(agent);
CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts);
CREATE INDEX IF NOT EXISTS idx_events_cost_bucket ON events(cost_bucket);
CREATE INDEX IF NOT EXISTS idx_traces_status ON traces(status);
CREATE INDEX IF NOT EXISTS idx_traces_spec_category ON traces(spec_category);

-- Views for dashboard
CREATE VIEW IF NOT EXISTS v_cost_by_agent AS
SELECT
  agent,
  COUNT(*) as total_events,
  SUM(cost_usd) as total_cost,
  AVG(cost_usd) as avg_cost_per_event,
  SUM(tokens_input + tokens_output) as total_tokens,
  SUM(tokens_cache_read) as total_cache_hits
FROM events
GROUP BY agent;

CREATE VIEW IF NOT EXISTS v_cost_by_bucket AS
SELECT
  cost_bucket,
  COUNT(*) as total_events,
  SUM(cost_usd) as total_cost,
  AVG(cost_usd) as avg_cost_per_event
FROM events
GROUP BY cost_bucket;

CREATE VIEW IF NOT EXISTS v_cost_by_trace AS
SELECT
  t.trace_id,
  t.spec_path,
  t.spec_category,
  t.status,
  COUNT(e.id) as total_events,
  SUM(e.cost_usd) as total_cost,
  MIN(e.ts) as started,
  MAX(e.ts) as ended,
  SUM(e.retry_count) as total_retries
FROM traces t
LEFT JOIN events e ON e.trace_id = t.trace_id
GROUP BY t.trace_id;

CREATE VIEW IF NOT EXISTS v_retry_rates AS
SELECT
  agent,
  COUNT(*) as total_specs,
  SUM(CASE WHEN retry_count = 0 THEN 1 ELSE 0 END) as first_pass_success,
  ROUND(100.0 * SUM(CASE WHEN retry_count = 0 THEN 1 ELSE 0 END) / COUNT(*), 1) as first_pass_rate,
  AVG(retry_count) as avg_retries
FROM events
WHERE event_type = 'task_complete'
GROUP BY agent;

CREATE VIEW IF NOT EXISTS v_cost_trend AS
SELECT
  DATE(ts) as day,
  agent,
  cost_bucket,
  SUM(cost_usd) as daily_cost,
  COUNT(*) as daily_events
FROM events
GROUP BY DATE(ts), agent, cost_bucket
ORDER BY day DESC;
