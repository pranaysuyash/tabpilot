# Recovery Toolkit (Additive-Only)

This toolkit enforces non-destructive recovery rules for this repository.

Policy:
- Allowed: new files and additive inserts.
- Forbidden: deletions, renames, and destructive replacements.

## Scripts
- `Recovery/scripts/create_safety_baseline.sh`
  - Captures git/index safety artifacts and OpenCode metadata snapshot.
- `Recovery/scripts/policy_diff_audit.sh`
  - Fails if there are deleted files, renamed files, or removed lines.
- `Recovery/scripts/policy_diff_audit_scoped.sh`
  - Same policy checks but restricted to selected pathspecs.
- `Recovery/scripts/state_integrity_check.sh`
  - Compares current status against baseline (`Recovery/safety/LATEST`).
- `Recovery/scripts/verify_recovery_wave.sh`
  - Runs policy checks and `swift build`, `swift test`.
  - Pass pathspecs to run scoped policy audit first.
- `Recovery/scripts/generate_opencode_forensics.sh`
  - Creates session inventory and review list metrics from OpenCode `.dat` snapshots.

## Standard flow
1. Run safety baseline.
2. Perform additive-only changes.
3. Run policy + state checks.
4. Run build/test verification.

Scoped example:
- `Recovery/scripts/policy_diff_audit_scoped.sh Sources/ChromeTabManager/Recovery Recovery`
- `Recovery/scripts/verify_recovery_wave.sh Sources/ChromeTabManager/Recovery`
