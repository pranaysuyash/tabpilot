# Decision Tables

## 1. Distribution Approach

| Option | Pros | Cons | Complexity | Support Burden | Launch Suitability | Best Current Choice | What Would Change Choice |
|--------|------|------|------------|----------------|-------------------|---------------------|--------------------------|
| **Mac App Store** | Easy discovery, automatic updates, trusted by users, handled by Apple | 30% fee, review delays, entitlement complexity, limited to MAS users | Low (already implemented) | Low (Apple handles most) | Poor (conflicts with stated intent) | ❌ | If MAS becomes primary goal or direct distribution proves too complex |
| **Direct Distribution (Website)** | Full control, no fees, immediate updates, aligns with stated intent | Requires building trust, handling payments/updates yourself, need notarization | Medium | Medium (handles payments, updates, support) | **Excellent** (matches intent, avoids MAS restrictions) | ✅ | If notarization/update complexity proves prohibitive |
| **Hybrid (Both)** | Best of both worlds, redundant distribution channels | Doubles maintenance burden, potential user confusion, complex entitlement handling | High | High | Poor (too much overhead for v1.0) | ❌ | If significant MAS demand emerges post-launch |

## 2. Entitlement/Verification Model

> **2026-03-26 update:** Decided on "No Verification in App." App has zero licensing code. Purchase happens on landing page via Dodo Payments hosted checkout. "Restore" is email lookup on landing page. See `PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md`.

| Option | Pros | Cons | Complexity | Support Burden | Launch Suitability | Best Current Choice | What Would Change Choice |
|--------|------|------|------------|----------------|-------------------|---------------------|--------------------------|
| **No Verification in App** — $19.99 to download, app works forever | Zero code in app, simplest possible, no backend, no DRM | No piracy protection, anyone with DMG can use it | **None** | Low | **Excellent** (matches $19.99 utility pricing) | ✅ | If piracy becomes a significant revenue problem |
| **Email-Record-Only (landing page)** — Dodo API confirms purchase, shows download link | Leverages payment provider, no key management | Requires email access for re-download | Low (landing page only) | Low | Good | ✅ (for download restore) | N/A — this IS the download restore mechanism |
| **License Key** | Works offline, harder to share, familiar to users | Friction during setup, key management overhead, piracy still possible | Medium | Medium (key loss/recovery support) | Poor (overkill for $19.99 utility) | ❌ | If app becomes high-value ($49+) |
| **Signed License File** | Secure, cryptographically verifiable, offline capable | Complex implementation, key distribution challenges | High | Medium-High | Poor (overkill for utility app) | ❌ | If app becomes high-value target for piracy |
| **In-App Entitlement API** | Seamless, automatic | Requires backend server, webhook handler, API keys | High | Medium | Poor (over-engineered for v1.0) | ❌ | If subscription model adopted later |
| **Honor-System (No Verification)** | Zero friction, simplest implementation | Zero piracy resistance | None | Low | Good for $19.99 utility | ✅ (same as chosen option) | N/A |

## 3. Payment Processor

| Option | Pros | Cons | Complexity | Support Burden | Launch Suitability | Best Current Choice | What Would Change Choice |
|--------|------|------|------------|----------------|-------------------|---------------------|--------------------------|
| **Dodo Payments** | Simple API, good for indie devs, handles VAT/GST, webhooks | Less established than Paddle, smaller ecosystem | Low | Low | **Excellent** | ✅ | If Lemon Squeezy offers significantly better features or pricing |
| **Lemon Squeezy** | Simpler tax handling, good UI, built-in license generation | Slightly less flexible, newer than Paddle | Low | Low | **Excellent** | ✅ | If Dodo proves problematic or Lemon Squeezy offers better terms |
| **Paddle** | More established, better fraud prevention, enterprise features | More complex, higher cost, overkill for simple utility | Medium | Low-Medium | Fair | ❌ | If fraud becomes significant issue or enterprise features needed |
| **Gumroad** | Very simple to set up, good for digital products | Limited features, poor tax handling, not ideal for SaaS | Very Low | Low-Medium | Poor | ❌ | Never - inadequate for recurring needs like updates |
| **Custom Stripe + Tax Handling** | Maximum control, flexible, industry standard | Significant development overhead, tax complexity, PCI concerns | High | Medium | Poor (over-engineered) | ❌ | If existing providers fail to meet needs or regulations change drastically |

## 4. Update Mechanism

| Option | Pros | Cons | Complexity | Support Burden | Launch Suitability | Best Current Choice | What Would Change Choice |
|--------|------|------|------------|----------------|-------------------|---------------------|--------------------------|
| **Sparkle Framework** | Industry standard, secure, automatic, delta updates | Adds dependency, requires key management | Medium | Low (after setup) | **Excellent** | ✅ | If a better, more secure alternative emerges |
| **Built-in Update Checker** | Full control, no external dependencies | Security risks if not done right, reinventing the wheel | Medium-High | Medium | Poor | ❌ | If Sparkle becomes unavailable or problematic |
| **Manual DMG Replacement** | Zero implementation complexity | Poor UX, users fall behind, high support burden | None | **High** | Poor | ❌ | Never - unacceptable for paid product with security needs |
| **No Updates** | Simplest possible | Unacceptable for paid product, security risks, poor UX | None | **High** | Poor | ❌ | Never - violates basic expectations for paid software |
| **OS-Integrated (App Store)** | Seamless, trusted | Requires MAS distribution | Low | Low | Poor (conflicts with direct dist intent) | ❌ | If distribution strategy changes to MAS |

## 5. Notarization Approach

| Option | Pros | Cons | Complexity | Support Burden | Launch Suitability | Best Current Choice | What Would Change Choice |
|--------|------|------|------------|----------------|-------------------|---------------------|--------------------------|
| **Apple Notarytool** | Official method, required for Gatekeeper, well-documented | Requires Apple Developer ID, adds build step | Medium | Low | **Excellent** | ✅ | If Apple changes requirements significantly |
| **Third-Party Notarization Service** | Potentially easier, less Apple dependency | Less control, additional cost, trust concerns | Medium | Low-Medium | Poor | ❌ | If Apple notarization becomes prohibitively difficult or expensive |
| **Distribute Unnotarized** | Zero complexity | Will not run on majority of user machines due to Gatekeeper | None | **Very High** | Poor | ❌ | Never - unacceptable for user experience |
| **Require Gatekeeper Disable** | Bypasses need for notarization | Terrible UX, security nightmare, unprofessional | None | **High** | Poor | ❌ | Never - unacceptable for security and UX reasons |

## 6. Analytics/Crash Reporting

| Option | Pros | Cons | Complexity | Support Burden | Launch Suitability | Best Current Choice | What Would Change Choice |
|--------|------|------|------------|----------------|-------------------|---------------------|--------------------------|
| **Privacy-First Anonymous Analytics** | Insights into usage, respects privacy, builds trust | Limited insights, requires careful implementation | Low | Low | **Good** | ✅ | If users strongly demand more detailed analytics |
| **Opt-In Crash Reporting** | Helps improve stability, user-controlled | Requires implementation, may get low uptake | Low | Low | **Good** | ✅ | If crash rate is extremely low or privacy concerns prevent any reporting |
| **Full-Featured Analytics with Opt-Out** | Maximum insights, industry standard | Privacy concerns, potential backlash, more complex | Medium | Low-Medium | Poor | ❌ | If privacy becomes major concern or regulations change |
| **No Analytics/Crash Reporting** | Simplest, maximum privacy | Blind spots in user behavior, no crash insights | None | Low | Poor | ❌ | Never - unacceptable for maintaining and improving product |
