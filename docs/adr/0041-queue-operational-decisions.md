# ADR 0041 — Real-time queue operational decisions (grilling session 8)

- **Status:** Accepted
- **Date:** 2026-07-22

Resolves the remaining `realtime-queue.md` §77 items:

- **One called entry per outlet + business date**, enforced by partial unique index (`UNIQUE(outlet_id, business_date) WHERE status = 'called'`). Matches the single `currentServingNumber` contract field; `called` is transient (start-service or skip frees it). Per-staff calling rejected for MVP — plural now-serving breaks the customer display contract.
- **One in-service entry per staff**, enforced by partial unique index (`UNIQUE(staff_id) WHERE status = 'in_service' AND staff_id IS NOT NULL`). One chair, one customer.
- **Skipped entries return to the END of the waiting queue** (`sort_order = max(waiting) + 1`); no pre-skip position memory. Staff reorder handles exceptions.
- **Priority: pure check-in order** for scheduled and walk-in alike; audited staff reorder (reason required) is the only override. No hidden scheduled-customer precedence.
- **Wait estimate: `peopleAhead × average service duration`** — average from today's booking snapshots at the outlet, service-catalog mean as fallback; labeled an estimate; `estimateQuality` reserved, not emitted yet.
- **Near-turn ("queue nearly reached") push deferred to post-MVP.** MVP customer pushes: check-in confirmed, called (+ recall, rate-limited), service completed, plus booking/payment events. Product brief §13.11 annotated accordingly.
- **Staff queue snapshot carries no phone numbers** — display number, first name, service, booking code, status, timestamps only. Contact details live in the permission-checked (`booking.read`) booking detail view.

Folded defaults recorded here: queue display = outlet `queue_prefix` (default `'A'`) + 3-digit zero-padded number (`A012`); queue numbers reset daily by construction (counter PK includes `business_date`); number gaps after rolled-back allocations are acceptable; queue aggregate version lives in `queue_counters.version` (no separate table); Flutter reconnect backoff 1 s → 30 s cap with jitter; client-side event dedup keeps the last 100 event IDs in memory.

Already resolved elsewhere: reorder in MVP 0019 · self-check-in 0014 · check-in window 0034 · WS namespace 0030 · Redis optionality 0035 · queue command concurrency 0028 · WS envelope 0023 · sort_order ordering 0038.
