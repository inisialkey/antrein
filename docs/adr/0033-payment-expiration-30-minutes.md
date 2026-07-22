# ADR 0033 — Online payment expiration: 30 minutes

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

Contract §146 leaves exact payment expiration open. Contract examples show ~15 minutes; Midtrans Snap defaults to 24h. Expiration releases the reserved slot, so the value trades payment-friction tolerance against slot lockup.

## Decision

30 minutes, configurable via `PAYMENT_EXPIRATION_MINUTES` (default 30). Set as Snap expiry on payment creation AND enforced server-side by the every-minute expiration job (provider expiry is a courtesy; ours is authoritative). On expiration: payment → `expired`, pending booking → `expired`, reservation row deleted (slot released), customer notified.

## Consequences

- VA/QRIS round-trips fit comfortably; abandoned checkouts block a slot ≤30 min.
- Contract examples showing 15-minute expiresAt are illustrative, not normative.
