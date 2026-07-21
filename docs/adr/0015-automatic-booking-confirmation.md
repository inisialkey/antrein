# ADR 0015 — Booking confirmation is automatic

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Product brief §34 left automatic vs manual booking confirmation open. Contract examples carry `bookingPolicy.automaticConfirmation: true`, and no journey, screen, or status transition for a manual "accept booking" step exists anywhere in the docs.

## Decision

Bookings confirm automatically:

- Pay-at-location: `confirmed` immediately at creation (slot validated transactionally).
- Online payment: `pending_payment` → `confirmed` on verified webhook.

No business-side accept/reject step in MVP. `bookingPolicy.automaticConfirmation` stays in the schema as a future toggle but MVP treats it as always `true`.

## Consequences

- Status machine stays exactly as documented in product brief §16.1.
- Businesses control intake via operating hours, staff schedules, lead time, and horizon — not per-booking approval.
- A future manual-approval mode would need a new status + doc updates first (per doc-precedence rules).
