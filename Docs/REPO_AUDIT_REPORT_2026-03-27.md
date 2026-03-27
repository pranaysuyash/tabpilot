# TabPilot: Repo-First Audit Report (v1.0)

## 1. Executive Summary
TabPilot is a high-utility macOS application designed with a "Security-First" philosophy. The repository reveals a sophisticated engineering foundation (Swift Actors, Hardware-backed signing) that is currently hindered by significant maintainability debt. The presence of redundant recovery files and a manual build-pipeline makes the repo high-risk for multi-developer collaboration and safe iteration.

- **Overall Engineering Grade**: **B**
- **Overall Score**: **7.8 / 10 (Weighted)**
- **Maturity Assessment**: **Midstage (Pre-Launch)**. The core is stable, but the surrounding tooling is "prototype-grade."

### Biggest Strengths
- **Hardware-Backed Trust**: Secure Enclave integration for audit logging is exemplary.
- **Zero-Dependency Core**: Package.swift reveals a purely native footprint.
- **Strict Concurrency**: Swift 6 ready with high-fidelity actor isolation.

### Biggest Risks
- **Recovery File Bloat**: 23+ redundant `*Recovery.swift` files cause namespace pollution and logical drift.
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
| **Maintenance** | Hygiene | Recovery file bloat | **D** | 3 | `Managers/`, `Models/` |
| **Maintenance** | Build | Bundling scripts | **C** | 5 | `run.sh:67` |
| **Quality** | Testing | Unit Coverage | **D** | 3 | `Tests/` |
| **UI** | Decomposition | View/VM separation | **B-** | 6 | `SuperUserTableView.swift` |

---

## 4. Key Findings by Area

### 🟢 REPO-001 (P0): Recovery File Redundancy
- **Area**: Maintainability / Hygiene
- **Path**: Multiple (`Managers/`, `Models/`, etc.)
- **Severity**: **P0** (Critical blocker for team scale)
- **Evidence**: `AutoCleanupManagerRecovery.swift`, `TabEntityRecovery.swift`, etc.
- **Why it matters**: Developers must navigate 2x the source files. High risk of fixing bugs in the wrong file.
- **Fix Direction**: Delete all `*Recovery.swift` files once core logic is verified.

### 🔴 REPO-002 (P0): Unstable Tab Identifiers
- **Area**: Persistence Reliability
- **Path**: `ChromeController.swift:60`
- **Severity**: **P0**
- **Evidence**: `String(contentString.hashValue)`
- **Inferred Consequence**: Tab history and "Undo" will fail after every app restart.
- **Fix Direction**: Replace `.hashValue` with SHA256/MD5.

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
| **REPO-001** | Purge all `*Recovery.swift` | **P0** | Low | `/` search for "Recovery" returns 0 hits (excluding actual logic). |
| **REPO-002** | Correct Tab ID Hashing | **P0** | Med | `stableTabId` returns same ID for same URL/Title across launches. |
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
