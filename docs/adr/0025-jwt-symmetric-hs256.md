# ADR 0025 — Access tokens signed with symmetric HS256 in MVP

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

Docs allow symmetric for MVP with asymmetric as "production direction". Only one service (the API itself, REST + WebSocket gateway) ever verifies tokens in MVP.

## Decision

HS256 with `JWT_ACCESS_SECRET` (separate `JWT_REFRESH_SECRET` reserved; refresh tokens are opaque, not JWTs). Claims per auth doc: `sub`, `sid`, `type`, `iat`, `exp`, `iss: antrein-api`, `aud: antrein-mobile`.

## Consequences

- Zero key management now; switching to RS256/EdDSA is config + verification change behind the same auth service when a second verifier appears.
- Secret rotation = env change + accepted transient 401s (15-min blast radius).
