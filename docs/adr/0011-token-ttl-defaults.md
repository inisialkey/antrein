# ADR 0011 — Token lifetimes: 15-minute access, 30-day refresh

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

`docs/backend/authentication.md` §72 and `backend-brief.md` §114 list exact access- and refresh-token lifetimes as open decisions, while the documented `.env.example` carries `ACCESS_TOKEN_TTL_MINUTES=15` and `REFRESH_TOKEN_TTL_DAYS=30` as examples. Implementation (env validation, session expiry columns, tests) needs ratified values.

## Decision

Ratify the documented defaults:

- Access token (JWT): **15 minutes**.
- Refresh token (opaque, rotating): **30 days**, sliding on rotation; family revoked on reuse detection.

Both remain environment-configurable (`ACCESS_TOKEN_TTL_MINUTES`, `REFRESH_TOKEN_TTL_DAYS`); this ADR fixes the defaults, not hardcoded values.

## Alternatives

- Shorter access TTL (5 min): more refresh traffic on mobile networks for little security gain at MVP threat model.
- Longer refresh TTL (90 d): weakens the value of rotation/reuse detection for a portfolio product with no session-inactivity policy yet.

## Consequences

- Flutter refresh coordination (single-flight refresh, replay once) must tolerate a 15-minute cadence — already the documented design.
- Revisit alongside any production security review.
