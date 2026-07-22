# ADR 0039 — Authentication implementation decisions (grilling session 6)

- **Status:** Accepted
- **Date:** 2026-07-22

Resolves the remaining `authentication.md` §72 items:

- **Argon2id parameters:** node `argon2` library defaults pinned as named constants — memoryCost 64 MiB, timeCost 3, parallelism 4 (OWASP-aligned). Rehash-on-login when stored parameters differ (§9.4 path).
- **Refresh-token representation:** `sessionId.randomSecret` — backend splits on the separator, looks the session up by primary key, timing-safe-compares the hashed secret. Fully-opaque-with-lookup-id rejected (extra column for identical properties).
- **Reuse detection: strict.** A rotated token presented again marks the token family `compromised`, revokes all active descendants, returns `AUTH_REFRESH_TOKEN_REUSED`, requires full login, and emits a high-severity security event. No grace-window cache — Flutter's RefreshCoordinator serializes refreshes client-side.
- **Email verification: out of MVP.** Registration → `active` immediately; `email_verified_at` stays null; verification is an additive future flow (§61 future endpoints).
- **Suspension:** revokes all sessions (kills refresh); outstanding access tokens die within the 15-minute lifetime — no per-request session lookup. Sensitive mutation guards already re-check user status, closing the window where it matters.
- **Logout deactivates the device's push registration** (device → `inactive`); next login re-registers. A signed-out phone receives no booking/queue notifications.
- **Password-reset tokens:** 30-minute lifetime, single-use, hashed at rest; a new request invalidates prior unused tokens; completion revokes ALL active sessions (matches contract `allSessionsRevoked: true`).

Defaults recorded for context: active-session listing and login alerts stay out of MVP; device-metadata anomalies are log-only; security events go to structured logs with the audited subset (suspension, token reuse, manual revocation) also written to `audit_logs`; the Flutter token bundle is one serialized secure-storage value (atomic replacement per §20).

Doc corrections applied under ADR 0034 precedence: §9.1's letter+number composition rules replaced by length-only 8–128; §34's example rate limits annotated as superseded by the ADR 0034 values.
