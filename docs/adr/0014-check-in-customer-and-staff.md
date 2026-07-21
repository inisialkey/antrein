# ADR 0014 — Check-in: both customer self-service and staff-assisted

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Product brief §11.5 describes "customer or authorized staff initiates check-in" but §34 lists self-check-in vs staff-only as an open decision. The contract already defines `POST /bookings/{id}/check-in` with methods `customer_app`, `staff_assisted` (and `qr` later).

## Decision

Both paths ship in MVP:

- `customer_app` — booking owner checks in from the active-booking screen.
- `staff_assisted` — staff with queue permission on the booking's outlet.

Either way the backend validates booking status (`confirmed`), the configurable check-in window, and idempotency; a successful check-in creates the queue entry. QR remains out of MVP.

## Consequences

- Authorization on the endpoint is owner-OR-authorized-staff (two distinct policy branches, both tested).
- Remote early check-in abuse is bounded by the check-in window, not by who initiates.
- Walk-in flow (staff-created) is unaffected.
