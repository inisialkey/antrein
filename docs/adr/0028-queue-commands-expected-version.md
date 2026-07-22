# ADR 0028 — Queue staff commands use expectedVersion optimistic concurrency

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

Docs conflict: architecture §3.7/§24 lists queue commands under Idempotency-Key; `realtime-queue.md` (detailed spec) governs them with `expectedVersion` and reserves idempotency keys for check-in and recall.

## Decision

Follow `realtime-queue.md`:

- Staff commands (call, skip, return-to-waiting, start-service, complete-service, no-show, reorder) carry `expectedVersion`; a stale version updates zero rows → `409 QUEUE_VERSION_CONFLICT`; client refetches the snapshot and never auto-retries.
- Check-in keeps `Idempotency-Key` (it creates the queue entry).
- Recall is naturally idempotent (re-announce, no state change) — no key needed.

Architecture doc §3.7/§24's "queue command / service completion" idempotency entries are stale.

## Consequences

- No idempotency-key bookkeeping per staff tap; `queue_entries.version` is the single concurrency token.
- Double-tap of the same command = second request conflicts or is a no-op transition — both safe.
