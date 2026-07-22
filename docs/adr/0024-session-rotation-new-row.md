# ADR 0024 — Refresh rotation creates a new session row

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

`docs/backend/authentication.md` leaves the rotation strategy open: new `auth_sessions` row per rotation vs updating one row in place. The schema already carries `parent_session_id` and `token_family_id`.

## Decision

Each refresh creates a new `auth_sessions` row: old row → `status = 'rotated'`, new row references `parent_session_id` and inherits `token_family_id`. Reuse detection: presenting a token whose session is `rotated`/`revoked` revokes every active session in the family (`status = 'compromised'`). The daily cleanup job prunes expired chains.

## Consequences

- Full rotation audit trail; schema columns all earn their keep.
- Session count grows per refresh (~96/day/device at 15-min TTL) — cleanup job is required, not optional.
