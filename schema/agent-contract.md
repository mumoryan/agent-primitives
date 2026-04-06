# Agent Contract Schema v2
# Every agent definition (base or stub) must include these sections.
# Fields marked [required] must be present. Fields marked [optional] may be
# omitted if not applicable — omission means the default value applies.

# === IDENTITY ===
name: string                          # [required] unique agent identifier
transformation: string                # [required] "input → output" — supervisor routing signal
model: string                         # [required] model identifier
cost_bucket: enum                     # [required] orchestration | code_generation | world_building | review

# === TRIGGER ===
trigger_type: on_demand | periodic    # [required] default: on_demand
periodic_cadence: string | null       # [optional] e.g. "weekly" — only if trigger_type is periodic
trigger_source: supervisor | human | schedule  # [optional] who/what initiates — default: supervisor

# === INPUT CONTRACT ===
input:
  type: string                        # [required] semantic label for what supervisor passes
  schema:                             # [required] typed fields — supervisor validates before dispatch
    field_name: type                  #   at minimum one field
  sensitive_data: boolean             # [required] can this agent receive sensitive content (e.g. note text)?
  validation: string                  # [required] human-readable rule supervisor checks before dispatch

# === OUTPUT CONTRACT ===
output:
  type: string                        # [required] semantic label for what agent returns
  schema:                             # [required] typed fields the output must contain
    field_name: type
  confidence: boolean                 # [optional] does agent self-report confidence? default: false
  review_required: boolean            # [required] must output go through reviewer agent?
  human_approval: boolean             # [required] blocks on human sign-off before application?

# === TOOLS ===
tools:                                # [required] explicit allowlist — least privilege
  - name: string                      #   tool identifier
    type: raw | mcp                   #   PoC (raw) vs post-PoC (mcp) execution path
    scope: string                     #   file glob or resource identifier
    server: string | null             #   MCP server name — null for raw tools

# === EXECUTION ===
execution:
  max_retries: integer                # [required] per spec, before escalation to supervisor/human
  parallel: boolean                   # [optional] can multiple instances run simultaneously? default: false
  file_scope: string[]                # [required] directories this agent may write to
  protected_paths: string[]           # [optional] explicit deny list — enforced by guard-core.sh
  isolation: string | null            # [optional] scheduling constraints e.g. "no parallel with feature work"

# === SECURITY ===
security:
  injection_surface: string           # [required] where untrusted input could enter — "none" if not applicable
  sanitisation: string                # [required] how untrusted input is handled
