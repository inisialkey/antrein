# ADR 0022 — Business discovery is public (no authentication)

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Contract §38 marks discovery auth "optional"; §146 lists it undecided. Affects which endpoints get `@Public()` and how they are rate-limited.

## Decision

Public, unauthenticated: `GET /businesses`, `GET /businesses/{id}`, business services, staff, operating hours, availability. Authentication required from booking creation onward. Public endpoints are IP rate-limited and return only `active` businesses (ADR 0013) with no personal data.

## Consequences

- Browse-before-register funnel works; deep links to business pages render without a session.
- `@Public()` decorator usage is the explicit exception list per the global-guard default.
