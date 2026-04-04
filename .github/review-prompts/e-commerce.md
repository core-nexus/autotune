# E-Commerce & Payments Review

## Objective

Deep-dive audit of all billing, payments, subscriptions, credits, and payment
processor integration logic. This review covers the **money side** of the
platform — both revenue (subscriptions, purchases, contributions) and spend
(API costs, metered usage).

Errors here cost real money or silently give away free service. Treat every
finding with the gravity that financial code demands.

## Review Checklist

### Webhook Integrity

- [ ] Every webhook handler verifies the payment processor's signature before processing
- [ ] Idempotency: duplicate webhook events (same event ID) are detected and
      skipped without side effects
- [ ] All expected event types are handled; unexpected types are logged, not
      silently dropped
- [ ] Webhook handlers access the correct fields from the event payload
- [ ] Checkout/payment completion correctly provisions what was purchased
- [ ] Subscription lifecycle events correctly update local subscription records
- [ ] Invoice/payment events correctly grant entitlements with idempotency
- [ ] No race conditions between concurrent webhook deliveries for the same user

### Subscription Logic

- [ ] Subscription state transitions are correct:
  - New subscription → active
  - Upgrade/downgrade mid-cycle → correct tier, correct entitlement adjustment
  - Cancel at period end → still active until period end, then expires
  - Renewal → new period, entitlements granted
  - Payment failure → correct state (past_due, not prematurely canceled)
- [ ] Trial expiration detection works correctly
- [ ] Entitlement grants are idempotent (cannot double-grant for the same period)
- [ ] Mid-cycle upgrade grants calculate the correct difference
- [ ] Feature gating checks the correct subscription tier and status
- [ ] Free tier users get correct defaults and limits

### Credit / Token System (if applicable)

- [ ] Credit/token balance can never go below the configured minimum
- [ ] Balance caps or rollover limits are correctly enforced
- [ ] Deductions are atomic — no scenario where credits are consumed but
      the operation fails, or vice versa
- [ ] Every deduction creates a matching transaction record for audit
- [ ] Balance queries return consistent results (not stale or partially updated)
- [ ] Auto top-up (if implemented) triggers correctly and doesn't loop

### Cost Calculation

- [ ] Pricing lookups resolve the correct price for the item/service
- [ ] Currency conversions are correct (no off-by-100 or rounding errors)
- [ ] Fallback pricing doesn't silently undercharge or overcharge
- [ ] Insufficient-funds/credits checks happen BEFORE the operation, not after

### Checkout & Payment Flows

- [ ] Checkout session creation includes all required parameters
- [ ] Price IDs match the correct product and interval
- [ ] Success/cancel URLs are correct and don't leak session data
- [ ] Rate limiting on checkout creation is correctly enforced
- [ ] Payment method updates propagate to the correct customer record
- [ ] Card decline and payment errors surface to the user (not swallowed)

### Data Consistency

- [ ] Customer ID is set on the user record before any API call that requires it
- [ ] Subscription records in the database match the payment processor's state
- [ ] Credit/balance on the user record matches the sum of all transactions
      (or has a reconciliation mechanism)
- [ ] Rate limit records are cleaned up and don't accumulate unboundedly

### Currency & Math

- [ ] All monetary values use integers (cents/smallest unit), never floating-point
- [ ] No floating-point arithmetic on monetary amounts
- [ ] Rounding is explicit and consistent (platform's favor for billing,
      user's favor for credits granted)
- [ ] Currency is consistently handled (no mixed-currency assumptions)

## Severity Guide

- **CRITICAL**: User charged wrong amount, entitlements granted incorrectly,
  double billing, webhook bypass allowing free service
- **HIGH**: Subscription state machine bug, missing idempotency allowing double
  grants, auto top-up loop, checkout race condition
- **MEDIUM**: Stale subscription data displayed, rate limit bypassable,
  cost calculation off for rare cases
- **LOW**: Minor audit trail gaps, cosmetic billing display issues
