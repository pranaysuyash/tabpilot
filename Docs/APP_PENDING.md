# App Pending Work

**Last Updated:** March 27, 2026  
**Status:** Feature-complete, infrastructure work remaining

---

## 🚨 P0: Critical (Block Launch)

### 1. Apple Notarization
**Status:** ❌ NOT STARTED  
**Purpose:** Required for Gatekeeper compatibility on macOS  

**Actions:**
1. ❌ Set up notarization in build pipeline
2. ❌ Apple Developer account (if not already)
3. ❌ App-specific password for notarization
4. ❌ Integrate `xcrun notarytool` in build scripts
5. ❌ Staple notarization ticket to DMG

**Estimated Time:** 1-2 days  
**Priority:** P0 - App won't run on macOS without this  
**See:** `Docs/DISTRIBUTION_ARCHITECTURE.md`  

---

### 2. Sparkle Update Framework
**Status:** ❌ NOT STARTED  
**Purpose:** Auto-update mechanism for direct distribution  

**Actions:**
1. ❌ Add Sparkle.framework to project
2. ❌ Configure appcast.xml generation
3. ❌ Set up update server (can be S3)
4. ❌ Integrate update checks in app
5. ❌ Test update flow

**Estimated Time:** 2-3 days  
**Priority:** P0 - Users need update mechanism  
**See:** `Docs/UPDATE_PROCESS.md`  

---

## 🟢 P2: Post-Launch

### 3. Chrome Extension Enhancement
**Status:** ⚠️ EXISTS BUT NOT WIRED  
**Note:** Extension code exists but TabTimeHost was removed from app build. If needed:
- Requires separate TabTimeHost project
- Or restore TabTimeHost with proper SPM configuration

**Priority:** P2 - Not needed for launch  

---

### 4. Auto-Cleanup Rules Enhancement
**Status:** ⚠️ BASIC IMPLEMENTATION EXISTS  
**Location:** `AutoCleanupManager.swift`  

**Potential Enhancements:**
- More rule types (age-based, domain-based)
- Better UI for rule management
- Rule suggestions based on usage

**Priority:** P2 - Nice to have  

---

### 5. Safari Support
**Status:** ❌ NOT STARTED  
**Effort:** HIGH (requires separate adapters)  
**Priority:** P3 - Future roadmap  

---

## 📊 Summary

| Priority | Items | Time |
|----------|-------|------|
| P0 | Notarization + Sparkle | 1 week |
| P2 | Extension, Auto-cleanup | Post-launch |
| P3 | Safari support | Future |

---

## ✅ Completed

- [x] App code cleanup
- [x] Build passes
- [x] Tests pass (57/57)
- [x] Payment code removed
- [x] All features implemented

---

## 📁 See Also

- `Docs/LANDING_PAGE_PENDING.md` - Landing page work (separate project)
- `Docs/DISTRIBUTION_ARCHITECTURE.md` - Distribution docs
- `Docs/UPDATE_PROCESS.md` - Sparkle integration guide

---
*Last updated: 2026-03-27*
