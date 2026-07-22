# ADR 0030 — One WebSocket namespace; Redis adapter deferred to multi-instance

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

Contract §146 leaves namespace layout open. Architecture §32 says the single-instance MVP can run without Redis fan-out.

## Decision

- Single Socket.IO namespace `/realtime`; all scoping via rooms (`user:{id}`, `business:{id}`, `outlet:{id}`, `queue:{outletId}:{businessDate}`, `booking:{id}`, `queue-entry:{id}`), authorization enforced at room join.
- No Redis Socket.IO adapter until a second API instance exists; adding it is configuration (adapter registration), not architecture.

## Consequences

- Flutter maintains one socket connection; the event router dispatches by event type + resource.
- Room-join authorization is the single choke point to test.
- Horizontal-scaling checklist (arch §50) gains one explicit step: enable Redis adapter.
