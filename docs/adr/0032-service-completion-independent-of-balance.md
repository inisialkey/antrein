# ADR 0032 — Service completion does not require zero remaining balance

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

Contract §146 asks whether complete-service requires full payment. Barbershop reality: customer pays at the till after the haircut; product journey 11.7 says the remaining balance "is resolved" around completion, and pay-at-location confirmation is its own staff flow.

## Decision

Completion and payment are independent. `complete-service` succeeds with outstanding balance; the response (and business booking views) flag `remainingAmount > 0` so staff runs pay-at-location confirmation as its own audited step. Daily summary counts unpaid-completed bookings under pending payments.

## Consequences

- Queue flow never deadlocks on payment; no forced ordering at the till.
- An unpaid completed booking is a visible, reportable state — surfaced, not hidden.
