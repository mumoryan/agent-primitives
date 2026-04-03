---
# Layer 2: Stack context — Fastify/Bun/SQLite backend
# Reusable across any project using this stack
stack: ts-fastify
---

## [STATIC] Stack Knowledge

### Runtime + Language
- Bun — runtime, package manager, test runner
- TypeScript only — strict mode, no implicit any
- Never Node.js APIs when Bun equivalents exist

### Framework
- Fastify — HTTP server
- Plugins: @fastify/cors, @fastify/sensible
- Schema validation: Fastify's built-in JSON schema (ajv) — never Zod at the route level
- Zod acceptable for internal domain validation only

### Database
- SQLite via bun:sqlite — V1
- Every table must include: id, owner_id, world_id, created_at, updated_at
- owner_id and world_id on every row — schema must not need migration when multi-user arrives
- No raw SQL strings — use parameterised queries exclusively
- Migrations: plain SQL files in db/migrations/, numbered sequentially

### API design
- REST — no GraphQL for V1
- Route handlers return typed response objects — never raw JSON.stringify
- Errors use Fastify's built-in error handling via @fastify/sensible
- All routes require explicit input schema — no unvalidated inputs

### File structure
- src/routes/ — one file per resource
- src/plugins/ — Fastify plugins
- src/db/ — database access layer
- src/types/ — shared TypeScript types
- Never business logic in route handlers — extract to service functions

### Testing
- bun test — all tests
- Test files colocated: feature.ts → feature.test.ts
- Every route must have at least one happy-path and one error-path test
