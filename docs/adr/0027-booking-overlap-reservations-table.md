# ADR 0027 — Booking overlap protection via booking_reservations table

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

`database-design.md` §28 offers two strategies: (A) partial GiST exclusion constraint on `bookings` over a generated `schedule_range` column, or (B) a dedicated `booking_reservations` table carrying the exclusion constraint — recommended there as the fallback because Prisma handles generated columns + partial exclusion constraints poorly (drift detection).

## Decision

Strategy B. `booking_reservations(booking_id UNIQUE, staff_id, outlet_id, schedule_range tstzrange)` with:

```sql
ALTER TABLE booking_reservations
ADD CONSTRAINT booking_reservations_no_overlap
EXCLUDE USING gist (staff_id WITH =, schedule_range WITH &&);
```

Row inserted in the booking-creation transaction; deleted in the same transaction that moves a booking to any non-blocking status (`cancelled`, `expired`, `no_show`, `completed`). Blocking statuses: `pending_payment, confirmed, checked_in, waiting, called, in_service`.

## Consequences

- Constraint is total (no partial predicate) — status-list changes touch application code, not the constraint.
- Reservation lifecycle must be transactional with status transitions — enforced by the bookings module, verified by concurrency integration tests.
- `bookings` table stays Prisma-friendly; the exclusion constraint lives in one raw-SQL migration.
