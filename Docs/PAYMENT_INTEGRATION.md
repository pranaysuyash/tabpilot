# Payment Integration

> **SUPERSEDED — 2026-03-26**
> This document describes the payment integration approach. 
> **Current architecture:** Purchase happens on the landing page only. App has zero payment/licensing code.
> See: `Docs/PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md`

## Overview

Direct distribution model — app has **zero payment/licensing code**. All purchase flow happens on the landing page. App only verifies entitlement via email lookup.

**See:** `Docs/PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md` for the architecture decision record.

---

## Purchase Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DIRECT DISTRIBUTION FLOW                           │
└─────────────────────────────────────────────────────────────────────────────┘

  USER                    LANDING PAGE              DODO                 BACKEND
   │                          │                      │                      │
   │  1. Visit landing page    │                      │                      │
   │─────────────────────────>│                      │                      │
   │                          │                      │                      │
   │  2. Click "Buy Now"      │                      │                      │
   │─────────────────────────>│                      │                      │
   │                          │                      │                      │
   │                          │  3. Checkout         │                      │
   │                          │─────────────────────>│                      │
   │                          │                      │                      │
   │                          │  4. Payment success  │                      │
   │                          │<─────────────────────│                      │
   │                          │                      │                      │
   │                          │                      │  5. Webhook          │
   │                          │                      │  (checkout.completed)│
   │                          │                      │─────────────────────>│
   │                          │                      │                      │
   │                          │  6. Show download    │  7. Record purchase │
   │  7. Show download link    │  link + S3 URL      │  (email, product_id, │
   │<─────────────────────────│                      │  timestamp)          │
   │                          │                      │                      │
   │  8. Download DMG from S3 │                      │                      │
   │<─────────────────────────│                      │                      │
   │                          │                      │                      │
   ▼                          ▼                      ▼                      ▼


  APP STARTS                    BACKEND API              DATABASE
       │                             │                       │
       │  9. User enters email        │                       │
       │     (EmailService saves)     │                       │
       │─────────────────────────────>│                       │
       │                             │                       │
       │                             │  10. GET /entitlement │
       │                             │  ?email={email}       │
       │                             │──────────────────────>│
       │                             │                       │
       │                             │  11. Check purchase   │
       │                             │      record exists    │
       │                             │<──────────────────────│
       │                             │                       │
       │  12. Return entitlement     │                       │
       │     { isLicensed: true }    │                       │
       │<─────────────────────────────│                       │
       │                             │                       │
       │  13. Unlock Pro features    │                       │
       │                             │                       │
       ▼                             ▼                       ▼
```

---

## Key Points

| Component | Responsibility |
|-----------|-----------------|
| **Landing Page** | Initiates Dodo checkout, displays download link after purchase |
| **Dodo Payments** | Handles checkout, payment processing, VAT/GST compliance |
| **Backend** | Receives webhooks, stores purchase records |
| **App** | Verifies entitlement via email only — no payment logic |

---

## Backend Components

### Webhook Handler
- **Endpoint:** `POST /api/webhooks/dodo`
- **Triggered by:** `checkout.completed` event from Dodo
- **Actions:**
  1. Verify webhook signature
  2. Extract `customer_email`, `product_id`, `dodo_session_id`
  3. Upsert record in database

### Entitlement API
- **Endpoint:** `GET /api/entitlement?email={email}`
- **Response:**
  ```json
  {
    "isLicensed": true,
    "productId": "pro-license",
    "purchaseDate": "2026-03-26T10:00:00Z"
  }
  ```

### Database Schema
```
Table: purchases
  - email (unique, indexed)
  - product_id
  - dodo_session_id
  - purchase_date
  - created_at
  - updated_at
```

---

## App Components

### EmailService
- Saves user email to local storage (Keychain/UserDefaults)
- Email is required for entitlement verification

### EntitlementService
- Calls backend API with user's email
- Returns entitlement status
- Result cached locally (7 day expiry)

### ProFeatureGate
- Checks entitlement before enabling Pro features
- Graceful fallback if network unavailable

---

## Security

- All API calls over HTTPS
- Webhook signature verification prevents spoofing
- Email-based lookup (no sensitive payment data on our servers)
- Rate limiting on entitlement API
- App does not store payment credentials

---

## Update Distribution

- Sparkle framework handles app updates
- DMGs hosted on S3 + CloudFront
- Update feed URL: `https://cdn.tabpilot.app/appcast.xml`
- SHA-256 checksums verify integrity

---

## What App Does NOT Do

- ❌ Initiate Dodo checkout
- ❌ Process payments
- ❌ Store credit card info
- ❌ Handle VAT calculations
- ❌ Manage license keys directly
