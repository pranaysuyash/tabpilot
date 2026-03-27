# Dodo Webhook Handler Sketch

## Endpoint

```http
POST /webhooks/dodo
```

## Purpose

Receives payment confirmation events from Dodo Payments after successful checkout completion.

## Request Format

Dodo sends a POST request with a JSON body:

```json
{
  "event": "checkout.completed",
  "checkoutId": "chk_abc123...",
  "customer": {
    "email": "user@example.com",
    "customerId": "cus_xyz789..."
  },
  "payment": {
    "amount": 1999,
    "currency": "USD",
    "status": "succeeded"
  },
  "product": {
    "productId": "com.pranay.chrometabmanager.lifetime"
  },
  "timestamp": "2026-03-26T12:00:00Z"
}
```

## Response

Return `200 OK` with JSON:

```json
{
  "status": "received"
}
```

## Handler Implementation (Node.js/Express example)

```javascript
const express = require('express');
const router = express.Router();

// Verify webhook signature from Dodo
function verifyDodoSignature(payload, signature, secret) {
  const crypto = require('crypto');
  const expected = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(payload))
    .digest('hex');
  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
}

router.post('/webhooks/dodo', async (req, res) => {
  const signature = req.headers['x-dodo-signature'];
  const secret = process.env.DODO_WEBHOOK_SECRET;

  // Verify webhook authenticity
  if (!secret) {
    console.error('Webhook secret is not configured');
    return res.status(500).json({ error: 'Webhook verification unavailable' });
  }

  if (!signature) {
    console.error('Missing webhook signature');
    return res.status(401).json({ error: 'Missing signature' });
  }

  if (!verifyDodoSignature(req.body, signature, secret)) {
    console.error('Invalid webhook signature');
    return res.status(401).json({ error: 'Invalid signature' });
  }

  const { event, customer, payment, product, checkoutId } = req.body;

  if (event !== 'checkout.completed') {
    // Acknowledge other event types without processing
    return res.status(200).json({ status: 'ignored', event });
  }

  if (payment.status !== 'succeeded') {
    console.log(`Payment not succeeded for checkout ${checkoutId}`);
    return res.status(200).json({ status: 'payment_not_completed' });
  }

  try {
    // Store purchase record in database
    await db.purchases.upsert({
      where: { email: customer.email.toLowerCase() },
      create: {
        email: customer.email.toLowerCase(),
        productId: product.productId,
        purchaseDate: new Date(),
        checkoutId: checkoutId,
        dodoCustomerId: customer.customerId,
        isActive: true
      },
      update: {
        productId: product.productId,
        purchaseDate: new Date(),
        checkoutId: checkoutId,
        dodoCustomerId: customer.customerId,
        isActive: true
      }
    });

    console.log(`Purchase recorded for ${customer.email}`);
    res.status(200).json({ status: 'recorded' });
  } catch (error) {
    console.error('Failed to record purchase:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

module.exports = router;
```

## Database Schema (Supabase/Postgres example)

```sql
CREATE TABLE purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  product_id TEXT NOT NULL,
  purchase_date TIMESTAMPTZ NOT NULL,
  checkout_id TEXT UNIQUE,
  dodo_customer_id TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_purchases_email ON purchases(email);
CREATE INDEX idx_purchases_checkout ON purchases(checkout_id);
```

## Flow Diagram

```text
┌─────────────┐      POST /webhooks/dodo      ┌──────────────────┐
│    Dodo     │ ──────────────────────────────▶│   Our Backend    │
│  Payments   │                               │                  │
└─────────────┘                               │ 1. Verify sig    │
                                              │ 2. Parse event    │
                                              │ 3. Check status   │
                                              │ 4. Upsert DB      │
                                              └────────┬─────────┘
                                                       │
                                                       ▼
┌─────────────┐      200 OK              ┌──────────────────┐
│    Dodo     │ ◀────────────────────────│    purchases     │
│  (confirm)  │                          │      table       │
└─────────────┘                          └──────────────────┘
                                                       │
                                              When user calls
                                              /verify-purchase
                                                       ▼
                                              ┌──────────────────┐
                                              │ Returns isLicensed
                                              │ based on DB query
                                              └──────────────────┘
```

## Notes

- Always return `200 OK` quickly to prevent Dodo from retrying
- Process heavy logic asynchronously if needed
- Store `is_active=false` instead of deleting for refund handling
- Consider adding a refund event handler for `checkout.refunded`
