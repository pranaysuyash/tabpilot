# Comprehensive Implementation Plan - All Pending Tasks

**Date:** March 26, 2026  
**Scope:** All 13 pending tasks (P0, P1, P2)  
**Approach:** Phased implementation with subagents  
**Documentation:** Comprehensive  
**Testing:** End-to-end  

---

## PHASE 1: P0 CRITICAL TASKS (Week 1)

### Task 1: Strip Payment/Licensing Code from App
**Priority:** P0 | **Time:** 1 day | **Risk:** Medium  

**Files to DELETE:**
1. `Sources/ChromeTabManager/Services/DodoPaymentsService.swift`
2. `Sources/ChromeTabManager/Services/PaymentServiceProtocol.swift`
3. `Sources/ChromeTabManager/Services/EntitlementService.swift`
4. `Sources/ChromeTabManager/Services/EmailService.swift`
5. `Sources/ChromeTabManager/Models/CheckoutSession.swift`
6. `Sources/ChromeTabManager/Views/PaywallView.swift`
7. `Sources/ChromeTabManager/Features/License/LicenseController.swift`

**Files to MODIFY:**
1. `Sources/ChromeTabManager/Licensing.swift` - Remove all payment verification, keep minimal always-licensed state
2. `Sources/ChromeTabManager/AppViewModel.swift` - Remove license gate checks
3. `Sources/ChromeTabManager/ChromeTabManager.swift` - Remove PaywallView references

**Verification:**
- Build succeeds
- Tests pass
- No PaywallView references remain
- App launches without payment code

**Subagent:** Code-cleanup specialist  
**Dependencies:** None  

---

### Task 2: Wire Landing Page Dodo Checkout
**Priority:** P0 | **Time:** 2-3 hours | **Risk:** Low  

**Location:** `chrome-tab-manager-landing/script.js` lines 99-124  

**Actions:**
1. Get actual Dodo Payments checkout URL from Dodo dashboard
2. Replace placeholder URL in script.js
3. Configure success_url in Dodo to: `https://tabpilot.app/download.html`
4. Test checkout flow
5. Handle errors gracefully

**Verification:**
- Click "Buy Now" opens Dodo checkout
- Successful payment redirects to download.html
- Failed payment shows error

**Subagent:** Frontend integration specialist  
**Dependencies:** None (can use placeholder URL for testing)  

---

### Task 3: Download Delivery System
**Priority:** P0 | **Time:** 1-2 days | **Risk:** Medium  

**Components:**

#### A. DMG Hosting Setup
1. Create S3 bucket or CloudFront distribution
2. Upload notarized DMG
3. Configure public access
4. Get download URL
5. Update `download.html` line 8 with actual URL

#### B. Email Restore Flow
1. Implement Dodo API client in landing page
2. Create email → purchase lookup endpoint
3. Generate secure download links
4. Add rate limiting
5. Test restore flow end-to-end

**Files:**
- `chrome-tab-manager-landing/script.js` (lines 129-154)
- `chrome-tab-manager-landing/download.html`

**Verification:**
- Post-purchase email received
- Download link works
- Restore flow works with email
- Rate limiting prevents abuse

**Subagent:** Backend integration specialist  
**Dependencies:** Task 2 (Dodo setup)  

---

### Task 4: Apple Notarization Setup
**Priority:** P0 | **Time:** 1-2 days | **Risk:** Medium  

**Prerequisites:**
- Apple Developer account
- App-specific password for notarization

**Actions:**
1. Create build script for notarization
2. Configure `xcrun notarytool` with credentials
3. Integrate into CI/CD pipeline
4. Add DMG stapling step
5. Test notarized build on clean Mac

**Files:**
- New: `scripts/notarize.sh`
- Update: `.github/workflows/build.yml` or build pipeline

**Verification:**
- Build completes successfully
- Notarization succeeds
- Stapled DMG opens without Gatekeeper warning

**Subagent:** Build/DevOps specialist  
**Dependencies:** None  

---

### Task 5: Sparkle Update Framework
**Priority:** P0 | **Time:** 2-3 days | **Risk:** Medium  

**Actions:**
1. Add Sparkle.framework to project (SPM or CocoaPods)
2. Configure appcast.xml generation
3. Set up update server (S3 or dedicated)
4. Add update check menu item
5. Test update flow (old version → new version)

**Files:**
- Update: `project.pbxproj` (add framework)
- Update: `Info.plist` (add SUFeedURL)
- New: `scripts/generate_appcast.sh`
- Update: `ChromeTabManager.swift` (add update check)
- New: `MenuBarController.swift` (add Check for Updates menu)

**Verification:**
- Framework links successfully
- Appcast.xml generates correctly
- Update check finds new version
- Download and install works

**Subagent:** macOS integration specialist  
**Dependencies:** Task 4 (notarization)  

---

## PHASE 2: P1 IMPORTANT TASKS (Week 2)

### Task 6: Multi-Window Safety Fix
**Priority:** P1 | **Time:** 1-2 hours | **Risk:** Low  

**Issue:** `WindowGroup` can spawn multiple windows → command duplication  
**Fix:** Change to `Window` scene  

**File:** `Sources/ChromeTabManager/ChromeTabManager.swift`  

**Verification:**
- Only one window can exist
- No command duplication
- Window restores properly

**Subagent:** SwiftUI specialist  
**Dependencies:** None  

---

### Task 7: Fix Placeholder Links
**Priority:** P1 | **Time:** 2-3 hours | **Risk:** Low  

**7 placeholder links found in index.html:**
1. Line 35: Logo link → should go to `#hero`
2. Line 505: Restore link → wire to Dodo restore
3. Line 532: FAQ restore → wire to Dodo restore
4. Line 557: Privacy → create privacy.html
5. Line 558: Terms → create terms.html
6. Line 559: Support → create support.html
7. Line 560: Contact → link to email

**Files:**
- Update: `index.html`
- New: `privacy.html`
- New: `terms.html`
- New: `support.html`

**Verification:**
- All links work
- No 404 errors
- Legal pages present

**Subagent:** Frontend specialist  
**Dependencies:** None  

---

### Task 8: Screenshots & Hero Images
**Priority:** P1 | **Time:** 2-3 hours | **Risk:** Low  

**Screenshots to capture:**
1. Main scan results view (Standard) - HERO
2. Main scan results view (SuperUser) - HERO
3. Review Plan overlay
4. Cleanup Impact sheet
5. Statistics view
6. Tab scanning in progress

**Format:** PNG, 1200x800 or similar 16:10  
**Style:** Clean macOS window, light mode preferred  

**Files:**
- New: `images/screenshot-1.png` through `images/screenshot-6.png`
- Update: `index.html` (replace CSS mockup with actual images)

**Verification:**
- Images load correctly
- Responsive on mobile
- Look professional

**Subagent:** QA/Visual specialist (requires running app)  
**Dependencies:** App must build and run  

---

### Task 9: Privacy Policy Page
**Priority:** P1 | **Time:** 1-2 hours | **Risk:** Low  

**Options:**
1. Create `privacy.html` (recommended)
2. Use hosted service like iubenda
3. Link to Notion doc (temporary)

**Content Source:** `Docs/PRIVACY_POLICY.md`  

**Style:** Match landing page design  

**Verification:**
- Page loads
- Content accurate
- Linked from footer

**Subagent:** Content specialist  
**Dependencies:** None  

---

### Task 10: Support/Contact Page
**Priority:** P1 | **Time:** 30 min | **Risk:** Low  

**Simplest approach:** Link to email `support@tabpilot.app`  

**Alternative:** Create `support.html` with contact form  

**Verification:**
- Link works
- Email is monitored

**Subagent:** Frontend specialist  
**Dependencies:** None  

---

## PHASE 3: P2 NICE TO HAVE (Week 3+)

### Task 11: Chrome Extension Enhancement
**Priority:** P2 | **Time:** 2-3 hours | **Risk:** Low  

**Enhancements:**
1. Auto-install prompt in app
2. Better onboarding instructions
3. Visual indicator when extension is active

**Files:**
- Update: `extension/manifest.json` (if needed)
- Update: App UI for extension status

**Dependencies:** None  

---

### Task 12: Auto-Cleanup Rules Enhancement
**Priority:** P2 | **Time:** 2-3 days | **Risk:** Medium  

**Enhancements:**
1. Age-based rules (close tabs older than X days)
2. Domain-based rules (close specific domains)
3. Better UI for rule management
4. Rule suggestions based on usage patterns

**Files:**
- Update: `AutoCleanupManager.swift`
- Update: `AutoCleanupView.swift`

**Dependencies:** None  

---

### Task 13: Cross-Browser Support
**Priority:** P2 | **Time:** 2-3 weeks | **Risk:** High  

**Browsers:** Safari, Arc, Edge, Brave  

**Approach:**
1. Create BrowserAdapter protocol
2. Implement Chrome adapter (existing)
3. Implement Safari adapter (new)
4. Implement Arc/Edge/Brave adapters (new)
5. Add browser selection UI

**Files:**
- New: Multiple adapter files
- Update: `BrowserController.swift`
- Update: UI for browser selection

**Dependencies:** None  

---

## SUBAGENT ASSIGNMENTS

### Subagent 1: Backend & Build Specialist
**Tasks:** 1, 3, 4, 5  
**Focus:** Payment code removal, notarization, Sparkle, download system  

### Subagent 2: Frontend Specialist
**Tasks:** 2, 6, 7, 9, 10  
**Focus:** Landing page wiring, legal pages, support  

### Subagent 3: QA & Visual Specialist
**Tasks:** 8  
**Focus:** Screenshot capture, visual testing  

### Subagent 4: Enhancement Specialist
**Tasks:** 11, 12, 13  
**Focus:** P2 enhancements (post-launch)  

---

## TESTING STRATEGY

### Unit Tests
- Payment code removal doesn't break existing features
- License checks removed properly

### Integration Tests
- Dodo checkout flow end-to-end
- Download delivery works
- Sparkle update detection

### Manual Tests
- App launches without payment code
- Landing page checkout flow
- Notarized DMG on clean Mac
- Screenshots look good

### Visual Tests
- Screenshots at different viewports
- Landing page responsive design

---

## DOCUMENTATION PLAN

### During Implementation
1. Update PENDING_TASKS.md (mark items complete)
2. Create implementation notes for each task
3. Document any deviations from plan

### After Implementation
1. Update README.md with new setup instructions
2. Update BUILD.md with notarization steps
3. Create DEPLOYMENT.md for launch checklist
4. Update CHANGELOG.md

---

## ROLLBACK PLAN

If issues arise:
1. Keep copies of deleted files in `archive/` folder
2. Use git to revert if needed (but don't push)
3. Document issues in `Docs/IMPLEMENTATION_ISSUES.md`

---

## SUCCESS CRITERIA

**P0 Complete When:**
- [ ] App builds without payment code
- [ ] Dodo checkout works end-to-end
- [ ] Download delivery works
- [ ] Notarized DMG opens on clean Mac
- [ ] Sparkle updates work

**P1 Complete When:**
- [ ] Multi-window fix prevents duplicates
- [ ] All placeholder links work
- [ ] Screenshots present and look good
- [ ] Privacy policy linked
- [ ] Support contact available

**P2 Complete When:**
- [ ] Chrome Extension enhancements done
- [ ] Auto-cleanup rules enhanced
- [ ] Cross-browser support implemented

**LAUNCH READY When:**
- All P0 complete
- All P1 complete (or acceptable to launch without)

---

## TIMELINE

**Week 1:** P0 Tasks (Foundation)
- Day 1-2: Task 1 (Strip payment code)
- Day 2-3: Task 4 (Notarization)
- Day 3-4: Task 5 (Sparkle)
- Day 4-5: Task 2-3 (Checkout + Download)

**Week 2:** P1 Tasks (Integration + Polish)
- Day 1: Task 6 (Multi-window)
- Day 1-2: Task 7 (Placeholder links)
- Day 2: Task 9-10 (Privacy + Support)
- Day 3-4: Task 8 (Screenshots)
- Day 5: Testing

**Week 3:** P2 Tasks (Enhancements)
- Day 1-2: Task 11 (Chrome Extension)
- Day 3-5: Task 12 (Auto-cleanup)
- Week 4+: Task 13 (Cross-browser)

**LAUNCH:** End of Week 2 or Week 3

---

## COMMUNICATION PLAN

**Daily Updates:**
- Progress on current task
- Blockers or issues
- Next steps

**Milestone Updates:**
- P0 complete
- P1 complete
- Ready for launch

---

## RISK MITIGATION

| Risk | Impact | Mitigation |
|------|--------|------------|
| Payment code removal breaks build | High | Test thoroughly, keep backups |
| Dodo integration issues | Medium | Use test mode, have fallback |
| Notarization fails | High | Test early, use Apple's tools |
| Sparkle complexity | Medium | Start with basic implementation |
| Screenshot quality | Low | Professional capture, editing |

---

**Plan Version:** 1.0  
**Ready for implementation:** YES  
