# Landing Page Pending Work

**Last Updated:** March 27, 2026  
**Status:** Design complete, integration pending

---

## 🚨 P0: Critical (Block Launch)

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

---

### 3. Landing Page Placeholder Links
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

---

## 🟡 P1: Important

### 4. Privacy Policy Page
**Status:** ❌ NOT STARTED  
**Purpose:** Legal requirement, builds trust  

**Content Sources:**
- `Docs/PRIVACY_POLICY.md` - Already written (adapt to web format)

**Estimated Time:** 1-2 hours  

---

### 5. Support/Contact Page
**Status:** ❌ NOT STARTED  
**Purpose:** Customer support channel  

**Options:**
- Simple contact form → Email
- Link to email: `support@tabpilot.app`
- Use help desk software (Zendesk, Help Scout)

**Estimated Time:** 30 minutes  

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

---

## 📁 Related Documentation

- `chrome-tab-manager-landing/` - Landing page source
- `Docs/PRIVACY_POLICY.md` - Privacy policy content
- `Docs/REFUND_POLICY.md` - Refund policy content
- `Docs/PAYMENT_ARCHITECTURE_DECISION_2026-03-26.md` - Payment architecture

---

## 🚀 Suggested Sequence

### Week 1: Checkout & Download
- Day 1-2: Dodo checkout wiring
- Day 3: DMG upload + download page
- Day 4: Email restore flow
- Day 5: Placeholder links

### Week 2: Legal & Assets
- Day 1-2: Privacy policy + support page
- Day 3-5: Screenshots + hero images

---
*Last updated: 2026-03-27*
