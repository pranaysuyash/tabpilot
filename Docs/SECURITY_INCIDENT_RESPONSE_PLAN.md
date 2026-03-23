# Security Incident Response Plan

This plan defines how Chrome Tab Manager responds to security incidents.

## 1. Scope

- Runtime tampering indicators (debugger/hooking/library injection)
- Code-signature validation failures
- Data integrity anomalies in security audit trail
- Dependency or CI supply-chain policy violations
- Abuse or compromise of licensing/pro purchase workflow

## 2. Severity Levels

- `SEV-1`: confirmed compromise, key material exposure, or widespread user impact
- `SEV-2`: high-confidence tamper signal or integrity break, limited user impact
- `SEV-3`: suspicious activity requiring validation, no confirmed compromise
- `SEV-4`: policy drift or preventive hardening issue

## 3. Response Roles

- Incident Commander: coordinates timeline and decisions
- Technical Lead: containment, triage, root-cause analysis
- Communications Lead: release notes, customer updates, stakeholder sync
- Recovery Owner: patches, verification, and post-incident hardening

## 4. Detection Sources

- `SecurityAuditLogger` (`Application Support/ChromeTabManager/Security/audit.jsonl`)
- Runtime protection warnings (`Logger.security`)
- CI security pipeline (`scripts/security-checks.sh`, `scripts/supply-chain-check.sh`)
- User-reported suspicious behavior

## 5. Response Procedure

1. Triage
- Classify severity and open incident record.
- Preserve security audit file and relevant logs as immutable artifacts.

2. Containment
- Pause risky release/deployment paths.
- Disable impacted workflows or features if abuse is active.

3. Eradication
- Patch vulnerable code path.
- Rotate affected signing or environment secrets where relevant.
- Remove malicious dependency/workflow changes.

4. Recovery
- Verify fix in CI + local `make security-test`.
- Confirm audit chain continuity and new event integrity.
- Publish patched build.

5. Postmortem
- Produce timeline, root cause, and corrective actions.
- Add preventive tests/checks and owner + due date per action.

## 6. Time Objectives

- Initial acknowledgment: within 1 hour for `SEV-1/SEV-2`
- Containment target: within 4 hours for `SEV-1`, same business day for `SEV-2`
- Customer-facing update cadence: every 24 hours for active `SEV-1/SEV-2`

## 7. Evidence Retention

- Retain incident logs, audit trails, and CI artifacts for at least 90 days.
- Preserve postmortems and action items in versioned docs.
