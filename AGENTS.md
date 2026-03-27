# AGENTS.md

This file defines the default collaboration workflow for human contributors and coding agents in this repository.

## Default branch strategy

1. Pull latest `main` locally.
2. Switch to `staging` for implementation.
3. Ensure `staging` is up to date with `main` (fast-forward only) before starting changes.
4. Implement, validate, and push updates to `origin/staging`.
5. Open/update PR: `staging` -> `main`.
6. Merge only when reviews are resolved and required checks pass.

## Guardrails

- Do **not** implement features directly on `main`.
- Keep changes minimal and scoped to the task.
- Preserve existing public APIs unless the task explicitly requires changes.
- Never delete methods/functions as a quick fix for warnings without explicit confirmation.
- Do not commit/push without explicit user approval in the current session.

## Verification expectations

Before claiming completion, verify with fresh evidence:

- Build passes.
- Tests pass.
- PR status is mergeable (for PR-related work).

## Documentation expectation

When branch workflow changes, update relevant docs so humans and agents stay aligned:

- `.agent/AGENTS.md`
- `Docs/SESSION_CONTEXT.md`
- `Docs/PROJECT_TRACKING.md`
- `Docs/RECOVERY_README.md`
- `Docs/AGENT_GUARD_README.md`
- `.github/copilot-instructions.md`
- `AGENTS.md`
- `README.md`
