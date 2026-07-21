# ADR 0018 — Default cancellation policy: 6h full / 2–6h 50% / <2h and no-show 0%

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Product brief §14.3 gives example cancellation values explicitly marked "examples, not final defaults". Refund calculation (M5/M6) and seed data need ratified defaults. Businesses can override per their policy configuration.

## Decision

Adopt the documented example as the seeded default:

```
fullRefundBeforeMinutes:    360   (> 6h before appointment → full eligible refund)
partialRefundBeforeMinutes: 120   (2–6h → partial refund)
partialRefundPercentage:    50
noShowRefundPercentage:     0     (< 2h and no-show → deposit non-refundable)
```

"Eligible refund" = amount actually paid online; pay-at-location bookings have nothing to refund.

## Consequences

- Matches contract example payloads — no contract edits.
- Partial-refund percentage applies to paid amount with integer IDR arithmetic (floor) — exact rule tested in M6.
