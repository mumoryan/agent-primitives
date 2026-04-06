# Agent Contract Schema

Standard contract structure for all agent definitions across projects.
Every base agent in `base/` and every project stub must conform to this schema.

See `agent-contract.md` for the full schema with field descriptions and defaults.

## Usage

Base agents (Layer 0+1) define the full contract. Project stubs (Layer 3)
override specific fields — anything not overridden inherits from the base.
The `merge-agent.sh` script in each project concatenates layers at session start.
