# Payment Integration TODO

## Status: External Dependency - To Be Completed at Landing Page

### Overview
Payment integration for TabPilot requires Dodo Payments or similar payment processor setup. This is intentionally **deferred until the landing page/marketing phase** when we have:
- Final pricing strategy
- Payment processor account setup
- Tax/legal compliance requirements
- Landing page with payment flow

### Current State
- Payment UI exists (subscription view, upgrade prompts)
- Payment verification logic is stubbed/mocked
- No actual payment processing implemented

### Implementation Requirements

#### Phase 1: Landing Page Setup
- [ ] Create landing page (tabpilot.app or similar)
- [ ] Set up Dodo Payments account
- [ ] Configure products/pricing in Dodo dashboard
- [ ] Implement webhook endpoints for purchase verification

#### Phase 2: App Integration
- [ ] Replace `DodoPaymentsService.swift` mock implementation
- [ ] Implement `verifyPurchase()` with actual Dodo API
- [ ] Implement `restorePurchases()` for existing customers
- [ ] Add receipt validation
- [ ] Handle edge cases (expired subscriptions, refunds, etc.)

#### Phase 3: Testing
- [ ] Test purchase flow with Dodo sandbox
- [ ] Test subscription renewal
- [ ] Test restore purchase functionality
- [ ] Test error handling (network failures, invalid receipts)

### Files Affected
- `Sources/ChromeTabManager/Services/DodoPaymentsService.swift`
- `Sources/ChromeTabManager/Views/SubscriptionView.swift`
- `Sources/ChromeTabManager/Managers/LicenseController.swift`

### Notes
- **Do NOT implement payment processing now**
- Current implementation uses mocked verification (always returns success)
- This is acceptable for development/testing
- Real payment integration is blocked until landing page is ready

### Related Documentation
- See `Docs/PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md` for architecture details
- See `Docs/IMPLEMENTATION_PLAN_ALL_TASKS.md` for integration steps

---

**Next Action:** Complete landing page and payment processor setup first, then return to this TODO.
