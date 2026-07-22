# ADR 0038 — Database implementation choices (grilling session 5)

- **Status:** Accepted
- **Date:** 2026-07-22

Resolves the remaining `database-design.md` §81 items:

- **Queue ordering:** plain `sort_order integer` (initialized from `queue_number`); reorder rewrites affected waiting rows transactionally. Fractional `position_key numeric(20,6)` rejected — solves scale barbershop queues never reach.
- **Booking code:** per-business daily sequence — `booking_code_counters(business_id, date)` with the same atomic-upsert pattern as `queue_counters`, formatted `ANT-YYYYMMDD-NNNN`, globally unique-constrained. Random suffix (collision retries, unreadable) and platform-wide counter (hot row, volume leak) rejected.
- **One-active-outlet:** MVP partial unique index `outlets_one_active_mvp_uq` IS applied; documented as dropped before any multi-outlet release.
- **Rating aggregates:** stored `rating_average`/`rating_count` on businesses and staff_profiles, updated inside the review-insert transaction (one review per booking → no correction path needed in MVP).
- **Webhook payloads:** redacted at write (strip card/PII fields not needed for reconciliation) into plain JSONB; no column encryption in MVP.
- **Outbox lifecycle:** `processed` rows deleted after 30 days by the daily cleanup job; `failed`/`dead_letter` retained until manually resolved. Delivery transport is not business history — that lives in status-history and audit tables.

Recorded for context (already settled by doc recommendation or M1 practice): membership permissions stay `jsonb`; Prisma migrations may contain manual SQL (standard practice since migration 001); `pg_trgm` search indexes land in migration 015; **RLS is formally rejected for MVP** — authorization is app-layer (membership/ownership/outlet checks), revisited only if the API ever stops being the sole database client.
