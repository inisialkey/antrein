# ADR 0023 — WebSocket event envelope uses nested resource {type, id}

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

The docs conflict: `01-system-architecture.md` §30 shows a flat `resourceId` field; `docs/backend/realtime-queue.md` §43 (the newer, detailed spec) uses a nested `resource: { type, id }` object plus a top-level `eventId`.

## Decision

Canonical envelope (realtime-queue.md wins):

```json
{
  "eventId": "evt_01J...",
  "type": "queue.entry.updated.v1",
  "occurredAt": "2026-07-21T08:00:00+07:00",
  "resource": { "type": "queue_entry", "id": "que_01J..." },
  "version": 7,
  "data": {}
}
```

`resource.type` lets one client-side router dispatch without parsing ID prefixes. Architecture doc §30's flat form is stale.

## Consequences

- Flutter `RealtimeEventRouter` keys on `type` + `resource.type`.
- Event payloads remain versioned (`*.v1`); adding optional fields stays non-breaking.
