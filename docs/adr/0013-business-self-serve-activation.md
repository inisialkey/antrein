# ADR 0013 — Business creation is self-serve and auto-active in MVP

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Business status lifecycle includes `pending_verification → active`, but the docs never say who activates a business or whether unverified businesses appear in discovery (product brief §34, api-contract §146). No admin interface exists in MVP scope.

## Decision

`POST /businesses` creates the business with status `active` immediately. `pending_verification` stays in the status enum (and DB CHECK constraint) reserved for a future moderation flow; nothing in MVP sets it. Discovery lists `active` businesses only.

## Consequences

- MVP demo needs no admin step or tooling to onboard a business.
- Contract example response for create business (`status: "pending_verification"`) must be updated to `active` — contract defect to fix in `docs/02-api-contract.md` §43.
- Revisit before any real public launch; flipping the default back to `pending_verification` is one line plus an activation path.
