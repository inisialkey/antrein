# ADR 0012 — One account holds customer and business roles

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Product brief §34 left open whether customer and business roles share one account. The API contract already leans shared: `/me` returns `roles: [customer, business_owner]` plus `businessMemberships` on one user object, and login returns both. M2 auth data model needs this settled.

## Decision

One `users` record per person. Every user is implicitly a customer; business capabilities derive entirely from `business_memberships` (owner/staff role + permissions). No separate business account type, no second registration flow. The Flutter app maps this to two navigation shells (customer mode / business mode); mode switching never re-authenticates.

## Consequences

- Auth module stays role-agnostic; authorization reads memberships per request.
- A user with zero memberships simply never sees business mode.
- Matches contract examples as-is — no contract changes.
