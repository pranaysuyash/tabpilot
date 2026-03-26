# Payment Architecture Decision — 2026-03-26

## Context

Reviewer feedback raised a fundamental question: **"Why is Dodo Payments integration in the app at all?"**

This triggered a full re-evaluation of the payment/distribution architecture for TabPilot.

---

## Reviewer Feedback (exact)

> "Dodo Payments integration: Code is scaffolded but purchase flow is not functional but wanted clarity why it should go in the app and not the landing page? My thought was user goes to page, buys, gets a link from s3 and done?"

---

## Exploration Findings

### App Codebase State (chrome-tab-manager-swift)

**Scaffolded but broken payment code exists in the app:**

| File | Status |
|------|--------|
| `Services/PaymentServiceProtocol.swift` | Protocol defined |
| `Services/DodoPaymentsService.swift` | Partially implemented — creates checkout session but never opens URL; `verifyPurchase()` always returns true on 200 (TODO in code) |
| `Services/EntitlementService.swift` | Talks to `https://api.tabpilot.app` which doesn't exist |
| `Services/EmailService.swift` | UserDefaults-backed email storage |
| `Licensing.swift` | LicenseManager with purchase/restore flow; DEBUG bypasses payment entirely |
| `Features/License/LicenseController.swift` | ObservableObject wrapper for LicenseManager |
| `Views/PaywallView.swift` | Paywall UI — fetches checkout URL but never opens it |
| `Models/CheckoutSession.swift` | Simple model |
| `Utilities/KeychainManager.swift` | License storage |

**What's missing (never implemented):**
- No URL scheme handler for `tabpilot://payment-success`
- No backend server (`api.tabpilot.app` doesn't exist)
- No webhook handler
- API keys are empty placeholders (`DODO_PAYMENTS_API_KEY` = `""`)
- Checkout URL is fetched but never opened in browser/webview
- In release builds, payment flow fails with `missingAPIKey` error

### Landing Page State (chrome-tab-manager-landing)

**Polished static site with zero wiring:**

| File | Status |
|------|--------|
| `index.html` (270 lines) | Full landing page with hero, features, pricing, how-it-works |
| `style.css` (859 lines) | Apple-inspired CSS, dark mode support |
| `script.js` (145 lines) | Smooth scroll, animations, navbar behavior |
| `plan.json` | Design plan |

**What's broken/missing:**
- "Download Free" buttons simulate "Opening App Store" — wrong distribution model
- "Buy Now — $19.99" button has no click handler — no Dodo checkout
- No download URL configured (no S3/CloudFront link)
- No Dodo Payments JS SDK integration
- No email capture form
- No "already purchased?" restore flow
- Branding says "Chrome Tab Manager" everywhere — should be "TabPilot"
- Footer says copyright 2026 but no privacy/support links

---

## Decision: Landing Page Purchase, No In-App Payment

### Chosen Architecture

```
┌─────────────────────────────────────────────────┐
│                  LANDING PAGE                    │
│              (tabpilot.app)                      │
│                                                  │
│  1. User clicks "Buy Now — $19.99"              │
│  2. Dodo Payments hosted checkout opens          │
│  3. User pays, gets post-purchase page           │
│     with DMG download link                       │
│  4. Download link also emailed to user           │
│                                                  │
│  "Already purchased? Enter your email"           │
│  → Dodo API confirms purchase                    │
│  → Shows download link again                     │
│                                                  │
└──────────────────────┬──────────────────────────┘
                       │
                       │ User downloads DMG
                       ▼
┌─────────────────────────────────────────────────┐
│                  TABPILOT APP                    │
│           (Notarized DMG via S3)                 │
│                                                  │
│  App just works. Full stop.                      │
│  No license check. No paywall. No gating.        │
│  No in-app payment code.                         │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Why This Over In-App Payment

1. **$19.99 one-time purchase** — not worth building DRM infrastructure
2. **Notarized DMG** — users can copy the `.app` regardless of license checks
3. **No server-side features** — everything is local, nothing to gate
4. **Dodo stores purchase records** — email lookup is the "restore" flow
5. **Standard pattern for indie macOS tools** — Raycast, CleanShot X, etc.
6. **Less code = fewer bugs** — no backend, no webhooks, no URL scheme handlers

### What About Security?

**Question:** Is email-only (enter email → get download link) too insecure?

**Answer:** No. Worst case: someone shares their email so a friend downloads the DMG. At $19.99, people who'd do this wouldn't have paid anyway. You're not losing revenue, you're gaining users. Dodo Payments is the gatekeeper, not your app.

---

## What Changes

### App Code — Strip These Files

| File | Action |
|------|--------|
| `Services/DodoPaymentsService.swift` | DELETE |
| `Services/PaymentServiceProtocol.swift` | DELETE |
| `Services/EntitlementService.swift` | DELETE |
| `Services/EmailService.swift` | DELETE |
| `Models/CheckoutSession.swift` | DELETE |
| `Licensing.swift` | SIMPLIFY — remove all payment/verification logic; app is always "licensed" |
| `Features/License/LicenseController.swift` | DELETE or simplify to trivial always-licensed state |
| `Views/PaywallView.swift` | DELETE |
| `Utilities/KeychainManager.swift` | KEEP (may be useful for other things) but remove license-specific code |
| `Info.plist` — `DODO_PAYMENTS_API_KEY`, `TABPILOT_API_KEY` entries | DELETE |

### App Code — Simplify Licensing

The app should have zero licensing logic. It's a downloaded DMG — if you have it, you paid for it (or you're trying it, which is fine for $19.99).

**If you want a free tier later:** do it on the landing page (e.g., "free download has a 7-day trial") — not in the app.

### Landing Page — Wire These

| Change | Details |
|--------|---------|
| Wire "Buy Now" button | Dodo Payments hosted checkout URL |
| Create post-purchase page | Shows DMG download link (S3 URL) |
| Add "Already purchased?" section | Email input → Dodo API lookup → show download link |
| Fix download buttons | Single "Download" button linking to S3 DMG (no free/pro split) |
| Fix branding | "Chrome Tab Manager" → "TabPilot" everywhere |
| Remove App Store simulation | `script.js:81-93` — replace with actual download link |
| Add privacy/support links | Footer |

---

## Decision: No Free Tier

**Decided:** No free tier. $19.99 to download, full app, no gating.

Rationale:
- No in-app licensing code = no code to split free/pro paths
- Free tier only makes sense if you have an in-app paywall funnel — which we're removing
- "Buy once, use forever" is the brand. Don't dilute it.
- If try-before-you-buy is needed later, handle it on the landing page (e.g., time-limited DMG)

**Impact on app code:** All free tier gating code (`canCloseTabs`, `dailyCloseCount`, `freeDailyCloseLimit`, PaywallView triggers) can be stripped. The app is always "Pro."

---

## Superseded Documents

The following docs describe the OLD in-app payment architecture and are now **outdated** (see this doc instead):

- `Docs/PAYMENT_INTEGRATION.md` — described in-app Dodo SDK + webhook + backend flow
- `Docs/ENTITLEMENT_VERIFICATION.md` — described in-app license verification + Keychain caching + license keys

---

## Related Projects

| Project | Path | Role |
|---------|------|------|
| TabPilot App | `/Users/pranay/Projects/chrome-tab-manager-swift/` | macOS app (source of truth for features) |
| Landing Page | `/Users/pranay/Projects/chrome-tab-manager-landing/` | Static site — purchase + download delivery |

---

## Summary for Other Agents

**What was decided:** Payment happens on the landing page, not in the app. The app has zero licensing/payment code. User buys on website → downloads DMG → app works forever.

**What needs to happen next:**
1. Strip payment/licensing code from the app (see table above)
2. Wire Dodo Payments checkout on landing page
3. Add post-purchase download page and email-based restore on landing page
4. Fix branding from "Chrome Tab Manager" to "TabPilot"
5. Strip free tier gating code from app (no free tier — see above)
