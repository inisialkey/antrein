# ADR 0040 — Booking/payment operational decisions (grilling session 7)

- **Status:** Accepted
- **Date:** 2026-07-22

Resolves the remaining `booking-payment.md` §102 items:

- **One pending online payment per booking**, enforced by partial unique index (`UNIQUE(booking_id) WHERE status = 'pending' AND provider <> 'pay_at_location'`). A failed/expired attempt may be replaced by one new payment row; the booking payment summary aggregates attempts.
- **Provider-creation failure: customer-driven retry only.** Temporary failure → `PAYMENT_PROVIDER_UNAVAILABLE`, payment stays `pending` without provider reference (`provider_creation_*` columns track attempts), retry re-invokes creation idempotently with the local payment ID as merchant reference. No background retry worker. The reservation holds until the 30-minute payment expiration (ADR 0033) releases booking + payment + reservation uniformly.
- **Late-payment policy ratified as specced (§30):** a verified provider success arriving after local expiration confirms the booking only if the reservation row still exists; otherwise the event goes to `manual_review` and the late payment is refunded. Never silently confirm over a released/rebooked slot. Integration-tested race.
- **Business-initiated cancellation:** full refund of net paid regardless of timing thresholds, mandatory reason code, `booking.manage` permission, audit record, customer notification — separate endpoint from customer cancellation. Thresholds (ADR 0018) apply to customer-initiated cancels only.
- **Pay-at-location methods:** all five documented labels allowed (`cash`, `qris_manual`, `bank_transfer_manual`, `card_terminal`, `other`) — operational receipt records, none independently verified.
- **Job cadence (env-configurable):** payment expiration every 60 s; provider and refund reconciliation every 5 min; reservation-consistency check daily.

The other 14 §102 items were already resolved: overlap + reservations 0027 · `any_available` out (algorithm deferred with the feature) 0019 · deposit rounding dormant 0017 · provider 0016 · expiration 0033 · completion balance 0032 · cancellation thresholds + no-show 0018 · payload retention + booking codes 0038 · rescheduling excluded (product brief §14.4) · verification gating moot (self-serve active, 0013).
