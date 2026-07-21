# ADR 0019 — First-demo scope: walk-ins and queue reorder in; "any available staff" out

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Product brief §34 left three optional-scope items to discretion: walk-in bookings in the first demo, staff manual queue reordering, and "any available staff" selection (a Could-Have).

## Decision

- **In:** walk-in bookings (staff-created, straight into the queue) — queue ordering rules already assume them.
- **In:** manual queue reorder by authorized staff, audited via `queue_reorders`, guarded by `queue.reorder` permission — contract and DB already spec it.
- **Out:** "any available staff" booking mode. `staffSelection.mode` accepts only `specific_staff` in MVP; `any_available` returns a validation error until implemented.

## Consequences

- Slot generation and the booking transaction stay single-staff-scoped (simpler conflict surface).
- Walk-in + reorder land in M7 as planned; no doc changes needed.
- Adding `any_available` later touches availability aggregation + assignment strategy — its own ADR then.
