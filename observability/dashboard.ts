import { Database } from "bun:sqlite";
import { resolve } from "path";

const PROJECT_DIR = process.argv[2] || resolve(import.meta.dir, "..");
const DB_PATH = resolve(PROJECT_DIR, "logs/observability.db");
const PORT = 3737;
const IDLE_TIMEOUT_MS = 10 * 60 * 1000; // 10 minutes

let shutdownTimer: Timer;

function resetShutdownTimer() {
  clearTimeout(shutdownTimer);
  shutdownTimer = setTimeout(() => {
    console.log("\nAuto-shutdown: no activity for 10 minutes.");
    process.exit(0);
  }, IDLE_TIMEOUT_MS);
}

function queryDb(sql: string): any[] {
  const db = new Database(DB_PATH, { readonly: true });
  try {
    return db.query(sql).all();
  } finally {
    db.close();
  }
}

const HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Loci — Observability Dashboard</title>
  <style>
    :root {
      --bg: #0a0a0a;
      --surface: #141414;
      --border: #2a2a2a;
      --text: #e0e0e0;
      --text-dim: #808080;
      --accent: #4a9eff;
      --green: #4ade80;
      --red: #f87171;
      --amber: #fbbf24;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', monospace;
      background: var(--bg);
      color: var(--text);
      padding: 24px;
      max-width: 1200px;
      margin: 0 auto;
    }
    h1 { font-size: 18px; color: var(--text-dim); margin-bottom: 24px; }
    h2 { font-size: 14px; color: var(--accent); margin: 24px 0 12px; text-transform: uppercase; letter-spacing: 1px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
    .card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 16px;
    }
    .card-title { font-size: 11px; color: var(--text-dim); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; }
    .card-value { font-size: 28px; font-weight: 600; }
    .card-value.cost { color: var(--accent); }
    .card-value.good { color: var(--green); }
    .card-value.warn { color: var(--amber); }
    .card-value.bad { color: var(--red); }
    table { width: 100%; border-collapse: collapse; margin-top: 8px; }
    th { text-align: left; font-size: 11px; color: var(--text-dim); text-transform: uppercase; letter-spacing: 1px; padding: 8px 12px; border-bottom: 1px solid var(--border); }
    td { padding: 8px 12px; font-size: 13px; border-bottom: 1px solid var(--border); }
    tr:hover td { background: rgba(74, 158, 255, 0.05); }
    .status-complete { color: var(--green); }
    .status-blocked { color: var(--red); }
    .status-in_progress { color: var(--amber); }
    .refresh { float: right; background: var(--surface); border: 1px solid var(--border); color: var(--text-dim); padding: 6px 12px; border-radius: 4px; cursor: pointer; font-size: 12px; }
    .refresh:hover { border-color: var(--accent); color: var(--accent); }
    .footer { margin-top: 32px; font-size: 11px; color: var(--text-dim); }
  </style>
</head>
<body>
  <button class="refresh" onclick="location.reload()">Refresh</button>
  <h1>Agent Observability Dashboard</h1>

  <div class="grid" id="summary-cards"></div>

  <h2>Cost by Agent</h2>
  <table id="cost-by-agent"></table>

  <h2>Cost by Bucket</h2>
  <table id="cost-by-bucket"></table>

  <h2>Traces</h2>
  <table id="traces"></table>

  <h2>Cost Trend (Daily)</h2>
  <table id="cost-trend"></table>

  <h2>Retry Rates</h2>
  <table id="retry-rates"></table>

  <div class="footer" id="footer"></div>

  <script>
    async function load() {
      const res = await fetch('/api/dashboard');
      const data = await res.json();

      // Summary cards
      const cards = document.getElementById('summary-cards');
      cards.innerHTML = [
        { title: 'Total Events', value: data.totalEvents, cls: '' },
        { title: 'Total Cost', value: '$' + (data.totalCost || 0).toFixed(4), cls: 'cost' },
        { title: 'Active Traces', value: data.activeTraces, cls: data.activeTraces > 0 ? 'warn' : '' },
        { title: 'Blocked', value: data.blockedTraces, cls: data.blockedTraces > 0 ? 'bad' : 'good' },
      ].map(c => '<div class="card"><div class="card-title">' + c.title + '</div><div class="card-value ' + c.cls + '">' + c.value + '</div></div>').join('');

      // Tables
      renderTable('cost-by-agent', ['Agent', 'Events', 'Total Cost', 'Avg Cost', 'Tokens', 'Cache Hits'], data.costByAgent, r => [r.agent, r.total_events, '$' + (r.total_cost || 0).toFixed(4), '$' + (r.avg_cost_per_event || 0).toFixed(4), r.total_tokens, r.total_cache_hits]);
      renderTable('cost-by-bucket', ['Bucket', 'Events', 'Total Cost', 'Avg Cost'], data.costByBucket, r => [r.cost_bucket, r.total_events, '$' + (r.total_cost || 0).toFixed(4), '$' + (r.avg_cost_per_event || 0).toFixed(4)]);
      renderTable('traces', ['Trace', 'Spec', 'Status', 'Events', 'Cost', 'Retries', 'Started', 'Ended'], data.traces, r => [r.trace_id ? r.trace_id.slice(0, 8) : '', r.spec_path || '', '<span class="status-' + r.status + '">' + r.status + '</span>', r.total_events, '$' + (r.total_cost || 0).toFixed(4), r.total_retries, r.started || '', r.ended || '']);
      renderTable('cost-trend', ['Day', 'Agent', 'Bucket', 'Cost', 'Events'], data.costTrend, r => [r.day, r.agent, r.cost_bucket, '$' + (r.daily_cost || 0).toFixed(4), r.daily_events]);
      renderTable('retry-rates', ['Agent', 'Total Specs', 'First Pass', 'First Pass Rate', 'Avg Retries'], data.retryRates, r => [r.agent, r.total_specs, r.first_pass_success, r.first_pass_rate + '%', r.avg_retries?.toFixed(1)]);

      document.getElementById('footer').textContent = 'Last refreshed: ' + new Date().toLocaleString() + ' · Auto-shutdown in 10 min of inactivity';
    }

    function renderTable(id, headers, rows, mapper) {
      const el = document.getElementById(id);
      if (!rows || rows.length === 0) { el.innerHTML = '<tr><td style="color:var(--text-dim)">No data</td></tr>'; return; }
      el.innerHTML = '<tr>' + headers.map(h => '<th>' + h + '</th>').join('') + '</tr>' + rows.map(r => '<tr>' + mapper(r).map(v => '<td>' + (v ?? '') + '</td>').join('') + '</tr>').join('');
    }

    load();
  </script>
</body>
</html>`;

const server = Bun.serve({
  port: PORT,
  fetch(req) {
    resetShutdownTimer();
    const url = new URL(req.url);

    if (url.pathname === "/api/dashboard") {
      try {
        const totalEvents = queryDb("SELECT COUNT(*) as c FROM events")[0]?.c || 0;
        const totalCost = queryDb("SELECT SUM(cost_usd) as c FROM events")[0]?.c || 0;
        const activeTraces = queryDb("SELECT COUNT(*) as c FROM traces WHERE status = 'in_progress'")[0]?.c || 0;
        const blockedTraces = queryDb("SELECT COUNT(*) as c FROM traces WHERE status = 'blocked'")[0]?.c || 0;
        const costByAgent = queryDb("SELECT * FROM v_cost_by_agent");
        const costByBucket = queryDb("SELECT * FROM v_cost_by_bucket");
        const traces = queryDb("SELECT * FROM v_cost_by_trace ORDER BY started DESC LIMIT 50");
        const costTrend = queryDb("SELECT * FROM v_cost_trend LIMIT 100");
        const retryRates = queryDb("SELECT * FROM v_retry_rates");

        return Response.json({
          totalEvents, totalCost, activeTraces, blockedTraces,
          costByAgent, costByBucket, traces, costTrend, retryRates
        });
      } catch (e: any) {
        return Response.json({ error: e.message }, { status: 500 });
      }
    }

    return new Response(HTML, { headers: { "Content-Type": "text/html" } });
  },
});

resetShutdownTimer();
console.log(`
  Agent Observability Dashboard
  http://localhost:${PORT}
  Project: ${PROJECT_DIR}
  Auto-shutdown after 10 minutes of inactivity.
  Press Ctrl+C to stop manually.
`);
