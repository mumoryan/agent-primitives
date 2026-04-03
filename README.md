# agent-primitives

Reusable base agent definitions and stack profiles for Claude Code multi-agent workflows.
Shared across projects — Loci and future SaaS, enterprise, or embedded projects.

## Structure

```
agent-primitives/
  base/          Layer 0+1 — identity + capability, model-agnostic, project-agnostic
  stacks/        Layer 2 — stack-specific context, reusable across projects
```

## Usage

Project-level agents (Layer 3) extend these base definitions via thin stubs
in `<project>/.claude/agents/`. The `merge-agent.sh` script in each project
concatenates base + stack + stub at session start, static sections first
for prompt caching eligibility.

## Layers

| Layer | Location | Content | Changes when |
|---|---|---|---|
| 0+1 | base/ | Identity, capability contract, output schema | Toolchain changes |
| 2 | stacks/ | Stack-specific rules and conventions | New project with different stack |
| 3 | project/.claude/agents/ | Project paths, constraints, locked decisions | Per feature / per sprint |
