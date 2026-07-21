# ADR 0017 — Deposits: fixed amount only in MVP

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Contract schema allows service deposit `type: none | fixed | percentage`. Product brief §34 asks fixed vs percentage; percentage requires a rounding rule (half-up vs round-down) that was itself an open decision.

## Decision

MVP supports `none` and `fixed` deposit types. `percentage` remains in the schema and DB CHECK constraint but is rejected by validation (`SERVICE_INVALID_DEPOSIT`) until enabled. The rounding decision is deferred with it.

## Consequences

- Deposit math is exact integer IDR — no rounding branch in M6.
- Enabling percentage later = validation change + rounding ADR + tests; no schema migration.
