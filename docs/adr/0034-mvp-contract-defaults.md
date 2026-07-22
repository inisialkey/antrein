# ADR 0034 — MVP contract defaults and limits

- **Status:** Accepted
- **Date:** 2026-07-22

Contract-level values the docs left unspecified are now normative in `docs/02-api-contract.md` (grilling session 3): password min 8 / max 128, length-only; auth rate limits (login 5/min/IP+email, register 3/min/IP, forgot 3/15min/IP+email, reset 5/min/IP); discovery geo params (`latitude`/`longitude`/`radiusKm`) reserved and ignored in v1 — name search + sort only; file uploads 5 MB max, JPEG/PNG/WebP, 10 gallery images per business; booking policy defaults lead 60 min / horizon 30 days / max 3 active bookings per customer per business; check-in window −30/+15 min around `scheduledAt`; idempotency retention 24 h general, 7 d for payment actions (`payment_events` dedupe rows are permanent).

All values are environment- or policy-configurable; this ADR fixes defaults, not hardcoded behavior. Recorded as one ADR rather than seven because each value is individually reversible — the contract document is the normative home; this record exists so the "why these numbers" trade-offs aren't re-litigated.
