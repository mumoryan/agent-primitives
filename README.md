# agent-primitives

Reusable base agent definitions and stack profiles for Claude Code multi-agent workflows.
Shared across projects — Loci and future SaaS, enterprise, or embedded projects.

## Structure

```
agent-primitives/
  schema/        Agent contract schema v2 — all agent definitions must conform
  base/          Layer 0+1 — identity + capability, model-agnostic, project-agnostic
  stacks/        Layer 2 — stack-specific context, reusable across projects
```

All base agents in `base/` conform to the contract schema defined in
`schema/agent-contract.md`. See `schema/README.md` for usage guidance.

## Usage

Project-level agents (Layer 3) extend these base definitions via thin stubs
in `<project>/.claude/agents/`. The `merge-agent.sh` script in each project
concatenates base + stack + stub at session start, static sections first
for prompt caching eligibility.

## Observability

Reusable observability tooling for agent-primitives projects.

```
observability/
  schema.sql        SQLite schema for event storage and dashboard views
  sync-events.sh    Syncs events.jsonl → observability.db (pass project dir as arg)
  dashboard.ts      Local browser dashboard served by Bun (pass project dir as arg)
```

Each project creates thin wrapper scripts that call these with the correct
project path. See any project's `scripts/` directory for examples.

## Infrastructure Scripts

Deterministic session lifecycle scripts. AI handles judgment; scripts handle
mechanics.

```
scripts/
  start.sh       Session bootstrap, prereqs, ID generation, hook verification
  dispatch.sh    Prepare worktree for agent instance
  end.sh         Teardown, log sync, worktree cleanup, archiving
```

Each project creates thin wrappers that call these with the correct project
path. See any project's `scripts/` directory for examples.

### Usage

```bash
# Start session (replaces running `claude` directly)
./scripts/loci-start.sh

# Inside Claude — orchestrator prepares worktrees before dispatch
bash scripts/loci-dispatch.sh frontend-implementer 1 features entry-sequence

# After Claude exits
./scripts/loci-end.sh
```

## Layers

| Layer | Location | Content | Changes when |
|---|---|---|---|
| 0+1 | base/ | Identity, capability contract, output schema | Toolchain changes |
| 2 | stacks/ | Stack-specific rules and conventions | New project with different stack |
| 3 | project/.claude/agents/ | Project paths, constraints, locked decisions | Per feature / per sprint |
