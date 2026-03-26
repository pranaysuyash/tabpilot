# ARCH-004: Manager Classes Lack Protocol Abstractions - Decision Record

**Date:** 2026-03-25
**Status:** DEFERRED

## Issue Summary

**Title:** Manager Classes Lack Protocol Abstractions

**Evidence:**
- AutoCleanupManager - hardcoded dependency on ChromeController.shared
- AutoArchiveManager - direct instantiation  
- SnapshotManager - direct instantiation

## Options Considered

### Option A: Create Protocols Now (Not Chosen)
Create `AutoCleanupManaging`, `Archiving`, `Snapshotting` protocols.

**Pros:**
- Enables dependency injection
- Easier to test with mocks

**Cons:**
- More code to maintain
- Indirection without immediate benefit
- No tests currently requiring mocks

**Effort:** ~2-3 hours

### Option B: Defer to When Needed (CHOSEN)

**Rationale:**
1. All managers are singletons with no alternative implementations
2. No immediate testing needs requiring mocks
3. Premature abstraction = YAGNI
4. Add protocols when actual use case emerges (e.g., CLI, widget, testing)

**Cost to defer:** Minimal - Swift makes adding protocols later straightforward

## Decision

**Choose:** Option B - Defer ARCH-004

## When to Revisit

Add protocols when:
- Writing unit tests that need mock managers
- Multiple implementations needed
- CLI or widget extension added
- Clear DI container usage established

## Current State

| Manager | Singleton | Protocol | Notes |
|---------|-----------|----------|-------|
| AutoCleanupManager | ✅ | ❌ | Keep as-is |
| AutoArchiveManager | ✅ | ❌ | Keep as-is |
| SnapshotManager | ✅ | ❌ | Keep as-is |

## Related Issues

- ARCH-001: ViewModel God Object (COMPLETED)
- ARCH-002: Browser Adapters Duplication (COMPLETED)
- ARCH-003: Thin Use Case Wrappers (COMPLETED)
- CONC-001: StatisticsStore Thread Safety (COMPLETED)
- CONC-002: Fire-and-Forget Logging (COMPLETED)
- CONC-003: Timer Invalidation (COMPLETED)
