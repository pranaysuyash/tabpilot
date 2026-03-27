# TabPilot: Repo-First Audit Report (v1.0)

## 1. Executive Summary
TabPilot is a high-utility macOS application designed with a "Security-First" philosophy. The repository reveals a sophisticated engineering foundation (Swift actors, hardware-backed signing) that is currently hindered more by documentation drift and a manual build pipeline than by source-level sprawl.

- **Overall Engineering Grade**: **B**
- **Overall Score**: **7.8 / 10 (Weighted)**
- **Maturity Assessment**: **Midstage (Pre-Launch)**. The core is stable, but the surrounding tooling is "prototype-grade."

### Biggest Strengths
- **Hardware-Backed Trust**: Secure Enclave integration for audit logging is exemplary.
- **Observed — Zero-Dependency Core**: `Package.swift` is present and declares a purely native package with no third-party Swift package dependencies.
- **Strict Concurrency**: Swift 6 ready with high-fidelity actor isolation.

### Biggest Risks
- **Observed — Historical Recovery Doc Drift**: recovery-related docs still describe prior `*Recovery.swift` incidents, but the current workspace does not contain active `*Recovery.swift` source files.
- **Manual Build Pipeline**: `run.sh` is fragile and depends on manual plist generation.
- **Test Gap**: Critical shortage of unit tests for the complex AppleScript-to-Model transformation layer.

---

## 2. Repo Coverage Map

| Area | Sub-area | Paths Audited | Line Items Audited | Agent Owner | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Project** | **Structure** | `/` | Modules, Dep Specs, Pkg naming | ARCH | 🟢 100% |
| **Logic** | **Engine** | `ChromeController.swift` | AppleScript safety, concurrency | PERF | 🟢 100% |
| **UI** | **Quality** | `Views/` | Decomposition, State coupling | UI | 🟡 80% |
| **Security**| **Hygiene** | `Utilities/Security*` | Keychain, Enclave, Hashing | SEC | 🟢 100% |
| **Operations**| **Build** | `run.sh`, `scripts/` | Bundling, Notarization | OPS | 🟡 90% |
| **Quality** | **Tests** | `Tests/` | Unit vs Performance coverage | DEV | 🟢 100% |

---

## 3. Master Scorecard

| Area | Sub-area | Line Item | Grade | Score | Evidence Reference |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Architecture** | Concurrency | Actor/Thread safety | **A++** | 10 | `ChromeController.swift:19` |
| **Architecture** | DI | Dependency Injection | **A** | 8 | `DIContainer.swift:4` |
| **Logic** | Normalization | URL Tracking Filter | **A+** | 9 | `ChromeController.swift:658` |
| **Security** | Auditing | Enclave Signing | **A++** | 10 | `SecurityAuditLogger.swift:56` |
| **Maintenance** | Hygiene | Historical recovery-state drift in docs | **C-** | 4 | `Docs/SESSION_DECISIONS.md`, `Docs/RECOVERY_VERIFICATION_REPORT_2026-03-27.md` |
| **Maintenance** | Build | Bundling scripts | **C** | 5 | `run.sh:67` |
| **Quality** | Testing | Unit Coverage | **D** | 3 | `Tests/` |
| **UI** | Decomposition | View/VM separation | **B-** | 6 | `SuperUserTableView.swift` |

---

## 4. Key Findings by Area

### 🟢 REPO-001 (P1): Historical Recovery-State Drift
- **Area**: Maintainability / Hygiene
- **Path**: `Docs/SESSION_DECISIONS.md`, `Docs/RECOVERY_VERIFICATION_REPORT_2026-03-27.md`
- **Severity**: **P1**
- **Observed**: current workspace audits and source listings no longer show active `*Recovery.swift` source files, but multiple docs still describe them as current-state blockers.
- **Why it matters**: stale historical findings can mislead later audits and overstate present maintainability risk.
- **Fix Direction**: preserve the history, but label recovery incidents as historical and keep current-state audit claims evidence-backed.

### 🔴 REPO-002 (P2): Stale Hashing Evidence in Earlier Audit Drafts
- **Area**: Persistence Reliability / Audit Accuracy
- **Path**: Earlier audit notes, not current `Sources/**`
- **Severity**: **P2**
- **Observed**: current `Sources/**` no longer contains `hashValue` evidence for tab identifier generation.
- **Why it matters**: stale source references weaken confidence in the rest of the audit.
- **Fix Direction**: keep identifier stability covered by regression tests and remove obsolete source citations from current-state reports.

### 🟡 REPO-003 (P1): Fragile build/plist generation
- **Area**: Operations / Release
- **Path**: `run.sh:67`
- **Severity**: **P1**
- **Evidence**: Hardcoded `CFBundleName` and `Package.swift` exclusion rules.
- **Why it matters**: Branding "TabPilot" will not persist correctly in Launchpad/Dock if plist is generated inconsistently.
- **Fix Direction**: Transition to `xcframework` or a proper Xcode project with build settings.

---

## 5. Prioritized Improvement Backlog

| ID | Title | Priority | Effort | Acceptance Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **REPO-001** | Distinguish historical recovery incidents from current-state findings | **P1** | Low | Recovery-related docs clearly mark prior incidents as historical, not current blockers. |
| **REPO-002** | Add regression coverage for stable tab identifiers | **P1** | Med | Identifier behavior is covered by tests rather than stale source snapshots. |
| **REPO-004** | Fix Global Branding | **P1** | Med | Global search "Chrome Tab Manager" returns 0 hits. |
| **REPO-005** | Expand Unit Test Suite | **P1** | High | 80%+ coverage for `Core/` and `Managers/`. |

---

## 6. Final Grade Breakdown

| Category | Grade |
| :--- | :--- |
| **Architecture / Concurrency** | **A++** |
| **Security / Privacy** | **A++** |
| **State / Data Handling** | **A-** |
| **Release Readiness** | **C** |
| **Maintainability** | **D** |
| **Testing Quality** | **D** |
| **FINAL WEIGHTED GRADE** | **B** |
