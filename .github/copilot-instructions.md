# Copilot Workspace Instructions

## Branching workflow (required)

- Keep `main` as the release/integration branch.
- Before starting work, update local `main` from `origin/main`.
- Do implementation work on `staging`.
- Keep `staging` fast-forwarded from `main` before new feature/fix work.
- Open/update PRs from `staging` into `main`.
- Merge to `main` only after review is complete and required checks are green.

## Agent behavior

- Do not make feature changes directly on `main`.
- Prefer additive, minimal, testable edits.
- Verify claims with fresh command output before reporting success.
- Do not commit or push unless explicitly requested in the current conversation.
- Load and follow local runtime rules in `.agent/AGENTS.md` when present.

## Safety notes

- If temporary backup branches are created for recovery/safety operations, clean them up after branch/PR state is stable.
- Keep generated artifacts and local machine files out of version control.
