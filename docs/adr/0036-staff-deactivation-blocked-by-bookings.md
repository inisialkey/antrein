# ADR 0036 — Staff deactivation blocked while future active bookings exist

- **Status:** Accepted
- **Date:** 2026-07-22

Deactivating a staff member who has future bookings in blocking statuses (`pending_payment`, `confirmed`, `checked_in`, `waiting`, `called`, `in_service`) fails with `409 STAFF_HAS_ACTIVE_BOOKINGS`, listing the blocking booking ids in `error.details`. The owner resolves them first (cancel with policy refunds, or let them complete). Contract §53's deferred-policy hedge is replaced by this rule.

Rejected: allow-and-keep (leaks an "inactive staff with active work" state into availability and queue logic) and auto-cancel (one tap mass-cancels customers — destructive default).
