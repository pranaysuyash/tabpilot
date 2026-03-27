# Landing Page & Distribution TODO

**Last Updated:** March 27, 2026  
**Purpose:** Single source of truth for all landing page, payment, and distribution tasks  
**Status:** App code complete — all external tasks listed here are pending  

---

## QUICK REFERENCE

### Key URLs to Configure
| Location | Current | Needed |
|----------|---------|--------|
| `chrome-tab-manager-landing/script.js:100` | `https://checkout.dodopayments.com/buy/tabpilot-lifetime` | Real Dodo checkout URL |
| `chrome-tab-manager-landing/download.html:8` | `https://releases.tabpilot.app/tabpilot-latest.dmg` | Real S3/CloudFront URL |
| `chrome-tab-manager-landing/index.html:505` | `#` placeholder | Restore page wiring |

### Documentation References
- Architecture: `Docs/PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md`
- Distribution: `Docs/DISTRIBUTION_ARCHITECTURE.md`
- Updates: `Docs/UPDATE_PROCESS.md`
- Notarization: `Docs/NOTARIZATION_GUIDE.md`
- Landing: `Docs/LANDING_PAGE_STRATEGIC_CONTEXT.md`

---

## PHASE 1: FOUNDATION (Week 1)

### 1.1 Dodo Payments Setup ❌
- [ ] Create Dodo Payments account
- [ ] Create product: "TabPilot Lifetime License"
- [ ] Set price: $19.99
- [ ] Get real checkout URL
- [ ] Get webhook secret
- [ ] Configure success_url to `https://tabpilot.app/download.html`

### 1.2 Landing Page Wiring ⚠️ PARTIAL
- [ ] Replace `const dodoCheckoutUrl = 'https://checkout.dodopayments.com/buy/tabpilot-lifetime'` with real URL
- [ ] Wire restore purchase section (`index.html:505`)
- [ ] Test checkout flow end-to-end

### 1.3 Download Delivery System ❌
- [ ] Set up S3 bucket: `tabpilot-downloads`
- [ ] Set up CloudFront distribution
- [ ] Configure custom domain: `releases.tabpilot.app`
- [ ] Upload notarized DMG
- [ ] Configure `download.html` with real DMG URL

### 1.4 Email Restore Flow ❌
- [ ] Implement Dodo API webhook handler
- [ ] Create purchase verification endpoint
- [ ] Email → Purchase lookup logic
- [ ] Rate limiting (5 requests/hour per email)
- [ ] Wire `script.js:129-154` restore flow

### 1.5 Remove Payment Code from App ❌
Files to delete from app:
- [ ] `Sources/ChromeTabManager/Services/DodoPaymentsService.swift`
- [ ] `Sources/ChromeTabManager/Services/PaymentServiceProtocol.swift`
- [ ] `Sources/ChromeTabManager/Services/EntitlementService.swift`
- [ ] `Sources/ChromeTabManager/Services/EmailService.swift`
- [ ] `Sources/ChromeTabManager/Models/CheckoutSession.swift`
- [ ] `Sources/ChromeTabManager/Views/PaywallView.swift`
- [ ] `Sources/ChromeTabManager/Features/License/LicenseController.swift`
- [ ] `Sources/ChromeTabManager/Utilities/KeychainManager.swift`

Files to simplify:
- [ ] `Sources/ChromeTabManager/Licensing.swift` — remove purchase/restore, keep always-licensed
- [ ] `Sources/ChromeTabManager/AppViewModel.swift` — remove license gate checks

**Reason:** Payment happens on landing page. App is $19.99 to download, works forever.

---

## PHASE 2: DISTRIBUTION (Week 1-2)

### 2.1 Apple Notarization ❌
- [ ] Apple Developer account ($99/year)
- [ ] Create App ID
- [ ] Create Developer ID certificate
- [ ] Create DMG notarization script
- [ ] Notarize and staple DMG
- [ ] Verify Gatekeeper compatibility

### 2.2 Sparkle Auto-Update ❌
- [ ] Add Sparkle.framework dependency
- [ ] Create appcast.xml template
- [ ] Set up update server: `updates.tabpilot.app`
- [ ] Generate DSA keys for update signing
- [ ] Integrate Sparkle in app
- [ ] Test update flow (simulate old version)

### 2.3 DMG Creation Script ❌
- [ ] Create `build_dmg.sh` script
- [ ] Include app icon in DMG
- [ ] Include EULA if needed
- [ ] Set DMG icon and layout
- [ ] Test on Intel and Apple Silicon

---

## PHASE 3: LANDING PAGE POLISH (Week 2)

### 3.1 Legal Pages ❌
- [ ] Create `privacy.html` (source: `Docs/PRIVACY_POLICY.md`)
- [ ] Create `terms.html`
- [ ] Create `support.html` (simple contact form)
- [ ] Wire footer links:
  - [ ] `index.html:557` — Privacy Policy
  - [ ] `index.html:558` — Terms
  - [ ] `index.html:559` — Support
  - [ ] `index.html:560` — Contact

### 3.2 Placeholder Links ❌
Fix all `href="#"` placeholders:
- [ ] `index.html:35` — Logo link → `#hero` or `/`
- [ ] `index.html:505` — Restore purchase → wired restore section
- [ ] `index.html:532` — FAQ restore → restore section
- [ ] `index.html:557` — Privacy → `privacy.html`
- [ ] `index.html:558` — Terms → `terms.html`
- [ ] `index.html:559` — Support → `support.html`
- [ ] `index.html:560` — Contact → `support.html`

### 3.3 Screenshots ❌
- [ ] Capture real app screenshots (6 needed):
  1. Main scan results view
  2. Review Plan overlay
  3. Cleanup Impact sheet
  4. Statistics view
  5. Tab scanning in progress
  6. Sidebar Tab Health gauge
- [ ] Compress images for web
- [ ] Replace CSS mockup with real images

### 3.4 Domain Setup ⚠️ PARTIAL
- [ ] Register `tabpilot.app` (or similar)
- [ ] Configure DNS:
  - `tabpilot.app` → S3/CloudFront (landing page)
  - `releases.tabpilot.app` → S3/CloudFront (downloads)
  - `updates.tabpilot.app` → S3/CloudFront (appcast)
- [ ] SSL certificates (auto via CloudFront)

---

## PHASE 4: TESTING & LAUNCH (Week 2-3)

### 4.1 End-to-End Testing ❌
- [ ] Purchase flow test (Dodo sandbox)
- [ ] Download flow test
- [ ] Restore purchase test
- [ ] DMG install test (clean macOS)
- [ ] Notarization test (Gatekeeper)
- [ ] Update check test
- [ ] Multi-browser test (Chrome, Safari, Firefox, Edge)

### 4.2 Release Checklist ❌
- [ ] All tests passing
- [ ] Security audit complete
- [ ] Performance benchmarks acceptable
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in all files
- [ ] Clean build (0 warnings)
- [ ] Archive created
- [ ] Code signed with Developer ID
- [ ] Notarized and stapled
- [ ] Smoke test on clean macOS
- [ ] Test on Intel Mac
- [ ] Test on Apple Silicon Mac
- [ ] Test on macOS 12, 13, 14, 15
- [ ] Beta testing (1 week)

### 4.3 Launch ❌
- [ ] GitHub release created
- [ ] Release notes published
- [ ] Landing page live
- [ ] Analytics configured
- [ ] Monitor crash reports
- [ ] Monitor user feedback

---

## SUMMARY

| Phase | Tasks | Status | Time |
|-------|-------|--------|------|
| 1. Foundation | 22 items | ❌ NOT STARTED | 1 week |
| 2. Distribution | 12 items | ❌ NOT STARTED | 1 week |
| 3. Landing Polish | 14 items | ❌ NOT STARTED | 1 week |
| 4. Testing & Launch | 16 items | ❌ NOT STARTED | 1 week |
| **Total** | **64 items** | **0/64** | **3-4 weeks** |

---

**Next Step:** Start with Phase 1 — Dodo Payments setup (1.1)
