# ADR 0029 — Payment status refresh queries the provider synchronously

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

Contract §146 asks whether `POST /payments/{id}/refresh` queries the provider synchronously. The key UX case: customer paid, webhook delayed, app resumed on a stale `pending` screen.

## Decision

Synchronous: refresh calls Midtrans status API in-request (short timeout), maps the result through the same idempotent transition path the webhook handler uses (event dedupe included), and returns the updated payment. On provider error/timeout, return the stored state with `refreshedFromProvider: false` — never fail the request for provider unavailability.

## Consequences

- Webhook and refresh converge on one transition function — no second state machine.
- Rate-limit refresh per payment (e.g. min interval) to keep customers from hammering Midtrans.
- Reconciliation worker still covers payments nobody refreshes.
