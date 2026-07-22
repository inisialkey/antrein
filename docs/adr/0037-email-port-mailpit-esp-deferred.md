# ADR 0037 — Password-reset email via EmailPort; Mailpit locally, ESP deferred

- **Status:** Accepted
- **Date:** 2026-07-22

No doc ever selected an email provider, but the forgot-password flow (M2) must deliver reset links. Decision: `EmailPort` with two MVP adapters — SMTP to Mailpit (local mail catcher in docker-compose, UI on :8025) for development, and a log/no-op fake for tests. A real ESP (Resend/SES/Postmark) is chosen only when a hosted demo environment exists; that choice is the remaining open item, tied to the demo-hosting decision.

Rejected: picking an ESP now (external account + domain verification for a locally-demoed feature) and returning the reset token in the API response (breaks the account-existence-privacy rule in contract §29).
