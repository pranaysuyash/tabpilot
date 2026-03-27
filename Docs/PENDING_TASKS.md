# TabPilot - Pending Tasks & Action Items

**Last Updated:** March 27, 2026  
**Status:** App code cleanup COMPLETE. Landing page & distribution work remaining.

---

## ✅ COMPLETED (2026-03-27)

### App Cleanup (All Done)
- [x] **Strip Payment Code** - PaywallView, LicenseController deleted. App now always-licensed.
- [x] **Delete 15 Recovery Files** - Unused backup code removed
- [x] **Fix TabTimeHost** - Removed from Package.swift (separate project if needed)
- [x] **Fix BrowserAdapters** - @unchecked Sendable warnings resolved
- [x] **Fix Performance Tests** - All 57 tests now pass

---

## 🚨 P0: CRITICAL (Block Launch)

### 1. Wire Landing Page Checkout
**Status:** ❌ NOT STARTED  
**Location:** `chrome-tab-manager-landing/script.js` lines 99-124  

```javascript
const dodoCheckoutUrl = 'https://checkout.dodopayments.com/buy/tabpilot-lifetime';
// TODO: Replace with your actual Dodo Payments checkout URL
```

**Actions Needed:**
1. ✅ Dodo Payments account setup
2. ✅ Create product in Dodo dashboard
3. ❌ Get actual checkout URL
4. ❌ Configure success_url to: `https://tabpilot.app/download.html`
5. ❌ Replace placeholder in script.js

**Estimated Time:** 2-3 hours  
**Priority:** P0 - Required for purchase flow  

---

### 2. Download Delivery System
**Status:** ❌ NOT STARTED  

**Components:**

#### A. DMG Hosting
- ❌ Upload notarized DMG to S3/CloudFront
- ❌ Get download URL
- ❌ Configure in `download.html` line 8:
  ```javascript
  const DMG_DOWNLOAD_URL = 'https://releases.tabpilot.app/tabpilot-latest.dmg';
  ```

#### B. Email Restore Flow
- ❌ Dodo API integration for purchase verification
- ❌ Email → Purchase lookup
- ❌ Secure download link generation
- ❌ Rate limiting (prevent abuse)

**Estimated Time:** 1-2 days  
**Priority:** P0 - Required for re-downloads  

---

### 3. Apple Notarization
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

### 4. Sparkle Update Framework
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

## 🟡 P1: IMPORTANT (Can Launch Without, Should Add Soon)

### 5. Landing Page Placeholder Links
**Status:** ❌ 7 PLACEHOLDER LINKS FOUND  

**Locations in index.html:**
1. Line 35: Logo link (should go to #hero or /)
2. Line 505: Restore purchase (needs wiring)
3. Line 532: FAQ restore link
4. Line 557: Privacy Policy
5. Line 558: Terms
6. Line 559: Support
7. Line 560: Contact

**Estimated Time:** 2-3 hours  
**Priority:** P1 - Required for legal compliance  

---

### 6. Screenshots & Hero Images
**Status:** ❌ NOT STARTED  

**Current State:** CSS-drawn window mockup  
**Needed:** Real app screenshots  

**Screenshots to Capture:**
1. Main scan results view (Standard/SuperUser) - HERO IMAGE
2. Review Plan overlay - Shows safety workflow
3. Cleanup Impact sheet - Proof of value
4. Statistics view - Awareness features
5. Tab scanning in progress - Shows personality
6. Sidebar Tab Health gauge - Unique metric

**Estimated Time:** 2-3 hours (capture + edit)  
**Priority:** P1 - Significantly improves conversion  

---

### 7. Privacy Policy Page
**Status:** ❌ NOT STARTED  
**Purpose:** Legal requirement, builds trust  

**Content Sources:**
- `Docs/PRIVACY_POLICY.md` - Already written

**Estimated Time:** 1-2 hours  
**Priority:** P1 - Required before launch  

---

### 8. Support/Contact Page
**Status:** ❌ NOT STARTED  
**Purpose:** Customer support channel  

**Estimated Time:** 30 minutes  
**Priority:** P1 - Required for customer trust  

---

## 🟢 P2: NICE TO HAVE (Post-Launch)

### 9. Chrome Extension Enhancement
**Status:** ⚠️ EXISTS BUT NOT WIRED  
**Note:** Extension exists but TabTimeHost was removed. If needed, requires separate project.

**Estimated Time:** 2-3 hours (if revived)  
**Priority:** P2  

---

### 10. Auto-Cleanup Rules Enhancement
**Status:** ⚠️ BASIC IMPLEMENTATION EXISTS  
**Location:** `AutoCleanupManager.swift`  

**Estimated Time:** 2-3 days  
**Priority:** P2  

---

### 11. Safari Support
**Status:** ❌ NOT STARTED  
**Effort:** HIGH (requires separate adapters)  
**Priority:** P3 - Future roadmap  

---

## 📊 SUMMARY BY PRIORITY

| Priority | Count | Time Estimate |
|----------|-------|---------------|
| **P0** (Critical) | 4 | 1 week |
| **P1** (Important) | 4 | 2-3 days |
| **P2** (Nice to Have) | 3 | 1 week |
| **Total** | 11 | 2-3 weeks |

---

## 🎯 LAUNCH READINESS

### Can Launch When:
- [x] App code cleanup complete ✅
- [x] Build passes ✅
- [x] Tests pass (57/57) ✅
- [ ] P0 items 1-4 complete (notarization + checkout + download)

### Should Add Before Launch:
- [ ] P1 items 5-8 (legal pages + screenshots)

### Can Add Post-Launch:
- [ ] P2 items 9-11

---

## 🚀 SUGGESTED LAUNCH SEQUENCE

### Week 1: Infrastructure
- Day 1-2: Apple notarization setup
- Day 3-4: Sparkle integration
- Day 5: DMG hosting + download page

### Week 2: Landing Page
- Day 1-2: Dodo checkout wiring
- Day 3: Privacy policy + support pages
- Day 4-5: Screenshot capture + hero images

### Week 3: Polish & Launch
- Day 1-2: End-to-end testing
- Day 3: Beta with real purchases
- Day 4: Final fixes
- Day 5: **LAUNCH** 🎉

---

**Note:** The app itself is feature-complete and production-ready. The remaining work is all distribution/infrastructure.

---
*Last updated: 2026-03-27*
