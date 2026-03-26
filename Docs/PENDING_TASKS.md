# TabPilot - Pending Tasks & Action Items

**Last Updated:** March 26, 2026  
**Status:** Landing page complete, app code cleanup needed, integrations pending  

---

## 🚨 P0: CRITICAL (Block Launch)

### 1. Strip Payment/Licensing Code from App
**Status:** ❌ NOT STARTED  
**Files to Delete:**
- `Sources/ChromeTabManager/Services/DodoPaymentsService.swift`
- `Sources/ChromeTabManager/Services/PaymentServiceProtocol.swift`
- `Sources/ChromeTabManager/Services/EntitlementService.swift`
- `Sources/ChromeTabManager/Services/EmailService.swift`
- `Sources/ChromeTabManager/Models/CheckoutSession.swift`
- `Sources/ChromeTabManager/Views/PaywallView.swift` ⚠️ EXISTS
- `Sources/ChromeTabManager/Features/License/LicenseController.swift`

**Files to Simplify:**
- `Sources/ChromeTabManager/Licensing.swift` - Remove payment verification, keep always-licensed state
- `Sources/ChromeTabManager/AppViewModel.swift` - Remove license gate checks

**Estimated Time:** 1 day  
**Priority:** P0 - App currently has broken/unused payment code  
**See:** `Docs/PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md`

---

### 2. Wire Landing Page Checkout
**Status:** ⚠️ PARTIALLY DONE (placeholders present)  
**Location:** `chrome-tab-manager-landing/script.js` lines 99-124  

**Current Code:**
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

**Estimated Time:** 2-3 hours (after Dodo setup)  
**Priority:** P0 - Required for purchase flow  

---

### 3. Download Delivery System
**Status:** ⚠️ PARTIALLY DONE (page exists, wiring needed)  

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

**Location:** `chrome-tab-manager-landing/script.js` lines 129-154  

**Estimated Time:** 1-2 days (requires Dodo API setup)  
**Priority:** P0 - Required for re-downloads  

---

### 4. Apple Notarization
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

### 5. Sparkle Update Framework
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

### 6. Multi-Window Safety Fix
**Status:** ❌ NOT STARTED  
**Location:** `ChromeTabManager.swift`  
**Issue:** `WindowGroup` can spawn multiple windows → command duplication  
**Fix:** Use `Window` scene instead  
**Estimated Time:** 1-2 hours  
**Priority:** P1  

---

### 7. Landing Page Placeholder Links
**Status:** ⚠️ 7 PLACEHOLDER LINKS FOUND  

**Locations in index.html:**
1. Line 35: `<a href="#" class="nav-logo">` - Logo link (should go to #hero or /)
2. Line 505: `<a href="#" id="restoreLink">` - Restore purchase (needs wiring)
3. Line 532: `<a href="#">restore page</a>` - FAQ restore link
4. Line 557: `<a href="#">Privacy Policy</a>` - Footer privacy
5. Line 558: `<a href="#">Terms</a>` - Footer terms
6. Line 559: `<a href="#">Support</a>` - Footer support
7. Line 560: `<a href="#">Contact</a>` - Footer contact

**Actions:**
- Create `privacy.html` or link to hosted privacy policy
- Create `terms.html` or link to hosted terms
- Create `support.html` or link to email
- Wire restore functionality (see #3 above)

**Estimated Time:** 2-3 hours  
**Priority:** P1 - Required for legal compliance  

---

### 8. Screenshots & Hero Images
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

### 9. Privacy Policy Page
**Status:** ❌ NOT STARTED  
**Purpose:** Legal requirement, builds trust  

**Options:**
1. Create `privacy.html` page
2. Use hosted privacy policy service (e.g., iubenda)
3. Link to Notion/Google Doc (temporary)

**Content Sources:**
- `Docs/PRIVACY_POLICY.md` - Already written
- Adapt to web format

**Estimated Time:** 1-2 hours  
**Priority:** P1 - Required before launch  

---

### 10. Support/Contact Page
**Status:** ❌ NOT STARTED  
**Purpose:** Customer support channel  

**Options:**
1. Simple contact form → Email
2. Link to email: `support@tabpilot.app`
3. Use help desk software (Zendesk, Help Scout)

**Estimated Time:** 30 minutes  
**Priority:** P1 - Required for customer trust  

---

## 🟢 P2: NICE TO HAVE (Post-Launch)

### 11. Chrome Extension Enhancement
**Status:** ⚠️ EXISTS BUT OPTIONAL  
**Location:** `extension/` folder  
**Purpose:** Time tracking per domain  

**Current State:** Functional but requires manual installation  
**Enhancement Options:**
- Auto-install prompt in app
- Better onboarding instructions
- Submit to Chrome Web Store (optional)

**Estimated Time:** 2-3 hours  
**Priority:** P2 - Not required for core functionality  

---

### 12. Auto-Cleanup Rules Enhancement
**Status:** ⚠️ BASIC IMPLEMENTATION EXISTS  
**Location:** `AutoCleanupManager.swift`  
**Current:** Timer-based with URL patterns  
**Enhancements:**
- More rule types (age-based, domain-based)
- Better UI for rule management
- Rule suggestions based on usage

**Estimated Time:** 2-3 days  
**Priority:** P2 - Nice feature, not core  

---

### 13. Cross-Browser Support
**Status:** ❌ NOT STARTED  
**Browsers:** Safari, Arc, Edge, Brave  
**Effort:** HIGH (requires separate adapters for each browser)  
**Priority:** P3 - Future roadmap item  

---

## 📊 SUMMARY BY PRIORITY

| Priority | Count | Time Estimate |
|----------|-------|---------------|
| **P0** (Critical) | 5 | 1-2 weeks |
| **P1** (Important) | 5 | 3-5 days |
| **P2** (Nice to Have) | 3 | 1-2 weeks |
| **Total** | 13 | 2-4 weeks |

---

## 🎯 LAUNCH READINESS

### Can Launch When:
- [x] Landing page design complete ✅
- [ ] P0 items 1-5 complete (app code + integrations)
- [ ] DMG download URL configured
- [ ] Dodo Payments checkout wired

### Should Add Before Launch:
- [ ] P1 items 7-10 (legal pages + screenshots)

### Can Add Post-Launch:
- [ ] P2 items 11-13 (enhancements)

---

## 🚀 SUGGESTED LAUNCH SEQUENCE

### Week 1: Foundation
- Day 1-2: Strip payment code from app (#1)
- Day 3: Multi-window safety fix (#6)
- Day 4: Apple notarization setup (#4)
- Day 5: Sparkle integration (#5)

### Week 2: Integration
- Day 1-2: Dodo Payments setup + wire checkout (#2)
- Day 3: Download delivery system (#3)
- Day 4: Privacy policy + support pages (#9, #10)
- Day 5: Screenshot capture + hero images (#8)

### Week 3: Polish & Launch
- Day 1-2: Testing end-to-end
- Day 3: Beta testing with real purchases
- Day 4: Final fixes
- Day 5: **LAUNCH** 🎉

---

## 📋 QUICK REFERENCE

### Critical URLs to Configure:
1. `chrome-tab-manager-landing/script.js:100` - Dodo checkout URL
2. `chrome-tab-manager-landing/download.html:8` - DMG download URL
3. `chrome-tab-manager-landing/index.html:505` - Restore page link

### Files to Delete (P0 #1):
See list above in section 1.

### Key Documentation:
- Architecture: `Docs/PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md`
- Distribution: `Docs/DISTRIBUTION_ARCHITECTURE.md`
- Updates: `Docs/UPDATE_PROCESS.md`
- Testing: `chrome-tab-manager-landing/TESTING.md`

---

**Last verified:** March 26, 2026
