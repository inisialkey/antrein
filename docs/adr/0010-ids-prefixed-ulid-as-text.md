# ADR 0010 — Public IDs: prefixed ULID stored as text

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

`docs/backend/database-design.md` §4.2 requires one consistent ID strategy before implementation (options: `text` or `uuid`). Every example in the docs renders IDs as `usr_01J...`, `bkg_01J...` — a resource prefix followed by a ULID-shaped value. IDs must be opaque, globally unique, hard to guess, and treated as strings by clients.

## Decision

- Format: `<prefix>_<ULID>` (uppercase Crockford base32), e.g. `usr_01J8FQ2Z5X9K3W7M1N4P6R8T0V`.
- Column type: `text` primary keys.
- Generated application-side by a single ID helper (`newId(prefix)`); the database never generates public IDs.
- Prefix registry lives with the helper: `usr, ses, prt, dev, biz, out, mem, inv, stf, svc, sch, cld, bkg, pay, evt, ref, que, ntf, rev, fil, adt, idm, obx, req` (extend there as tables land).
- Exception: `devices.id` is the client-supplied device identifier (contract: `PUT /me/devices/{deviceId}`), not server-generated.

## Alternatives

- Plain `uuid` column: native type, but loses the human-debuggable prefix used throughout the docs and API examples.
- UUIDv7 in text with prefix: equivalent properties; ULID chosen because doc examples are ULID-shaped and one library covers it.

## Consequences

- ULIDs are lexicographically sortable by creation time; do not expose sort order as an API guarantee (clients must treat IDs as opaque).
- Index size slightly larger than native uuid — acceptable at MVP scale.
