# ADR 0026 — One owned business per user in MVP

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

Contract §146 asks whether one user may own multiple businesses; `BUSINESS_LIMIT_REACHED` is already reserved in the error catalog.

## Decision

A user may own at most one business. Second `POST /businesses` → `422 BUSINESS_LIMIT_REACHED`. Being *staff* in other businesses is unlimited (memberships are the general mechanism); the cap applies to ownership only.

## Consequences

- Business mode never needs an owned-business picker.
- Raising the cap later is a validation-constant change; contract already reserves the error.
