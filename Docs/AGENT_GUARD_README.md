# Agent Guard Controls

This guard enforces two temporary safety controls:

## Session Git Workflow Note

- For this session, repository work is expected to happen on `staging`.
- Updates should be pushed to the `staging` PR branch for review before merge into `main`.
- The guard notes below describe shell restrictions only; merge readiness is determined through the PR workflow, not by bypassing `staging`.

1. `git` is restricted to staging-only actions (`git add` / `git stage`).
2. `rm` is blocked unless a recent functionality validation has passed.

## Install

```bash
./tools/agent-guard/install_guard.sh
```

## Activate in shell

```bash
source .agent/guard/activate.sh
```

After activation:
- `git commit`, `git push`, `git reset`, etc. are blocked.
- `rm` requires a fresh PASS validation report.

## Validate functionality (to unlock `rm`)

```bash
./tools/agent-guard/validate_functionality.sh
```

By default this runs:
- `swift build`
- `swift test`

On success it writes:
- `.agent/guard/last_validation.env`

The `rm` wrapper requires:
- `status=PASS`
- a recent timestamp (`<= AGENT_GUARD_MAX_AGE_SEC`, default 1800s)

## Notes

- Controls are path-based and only active when `activate.sh` is sourced.
- This design is additive and non-destructive; no existing repo files are removed.
