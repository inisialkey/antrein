# ADR 0016 — Payment gateway: Midtrans (sandbox)

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Docs shortlist Midtrans and Xendit behind `PaymentProviderPort`; the DB `provider` enum reserves `midtrans`, `xendit`, `sandbox`, `pay_at_location`. M6 builds webhook verification, checkout, expiration, and refunds against one real provider first.

## Decision

Midtrans, sandbox environment, via `MidtransPaymentAdapter` implementing `PaymentProviderPort`. Snap checkout (redirect URL) matches the contract's `checkout.type: "redirect_url"`. Webhook signature verification per Midtrans notification spec; raw body preserved on `POST /webhooks/payments/midtrans`.

## Alternatives

- Xendit: equally capable; adapter port keeps a later switch or addition cheap.
- Internal fake provider only: fastest but forfeits the real-gateway integration the portfolio explicitly demonstrates. A fake adapter is still built for tests.

## Consequences

- Payment methods in MVP = whatever Midtrans sandbox Snap exposes (QRIS, VA, e-wallets).
- Refund flow uses Midtrans refund API; provider-specific quirks stay inside the adapter.
