# A++ Dependencies & Config Roadmap

**Date:** March 23, 2026  
**Status:** Foundation Complete

## Phase 1: Foundation ✅
- [x] SPM package manager setup
- [x] No external dependencies (pure Apple frameworks)
- [x] Swift 6 compatible

## Phase 2: Validation (Future)
- [ ] Audit dependency update cadence
- [ ] Add config validation checks for build/runtime flags
- [ ] Add CI guardrails for incompatible dependency changes

## Current Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| None | - | Pure Apple frameworks only |

## Apple Frameworks Used
- SwiftUI - UI framework
- Combine - Reactive programming
- SwiftData - Persistence
- Security - Keychain, code signing
- WidgetKit - Widget extension
- AppKit - macOS integration

## Config Validation

### Build Flags
```swift
enum BuildConfiguration {
    case debug
    case release
}
```

### Runtime Flags
```swift
struct FeatureFlags {
    static var canCloseTabs: Bool
    static var canArchive: Bool
    static var canExport: Bool
}
```

## Best Practices Implemented
- No third-party dependencies
- Minimal external framework usage
- Swift native concurrency
- SwiftData for persistence

## CI Guardrails Needed
- [ ] Swift version enforcement
- [ ] Platform compatibility checks
- [ ] Dependency audit automation
