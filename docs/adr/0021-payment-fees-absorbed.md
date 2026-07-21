# ADR 0021 — Payment gateway fees absorbed by the business

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Product brief §34 left open whether provider fees are passed to the customer. Every contract example shows `requiredNow` exactly equal to the deposit/price with no fee line.

## Decision

Fees are absorbed: the customer pays exactly the snapshotted service price (or fixed deposit). `paymentSummary` carries no fee fields. Gateway fees are a business cost outside AntreIn's ledger in MVP.

## Consequences

- Payment amount calculation stays `amount = snapshot`; no per-method fee tables.
- Passing fees later = new contract fields + fee configuration + its own ADR.
