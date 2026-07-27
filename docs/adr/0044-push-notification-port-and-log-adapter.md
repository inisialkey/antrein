# 0044 — Push Notification Port Signature and Log Adapter Default

Date: 2026-07-26
Status: Accepted

## Context

M9 slice B implements the push pipeline (realtime-queue §52–§54): `notifications`
+ `notification_deliveries` rows created from the same outbox dispatch that
publishes WebSocket events. The docs sketch `PushNotificationPort` with slightly
different method signatures (backend-brief vs realtime-queue), and OneSignal is
the ratified provider (ADR 0022) — but no OneSignal credentials exist yet and
demo hosting (where they would live) is still an open decision.

## Decision

1. **Port signature** (single method, per-device):

   ```ts
   abstract class PushNotificationPort {
     abstract send(input: {
       pushProvider: string;
       pushToken: string;
       title: string;
       body: string;
       data: Record<string, string>;
     }): Promise<{ providerMessageId: string | null }>;
   }
   ```

   A thrown error means the send failed; the caller records it on the
   `notification_deliveries` row and never fails the queue mutation or the
   outbox dispatch (backend-brief §110). The whole notification step is
   best-effort: `notifyQueuePush` never throws, so an outbox row is never
   retried for a push/notification failure and cannot duplicate the in-app
   row. The accepted cost is that a DB failure mid-step loses that in-app
   notification — history is explicitly not a source of truth
   (database-design §42); outbox-event-id dedupe is the upgrade path if
   that ever matters.

2. **Adapter selection** mirrors `PAYMENT_PROVIDER`: `PUSH_PROVIDER` env,
   `log` (default — logs the send, returns a deterministic message id) or
   `none` (port resolves to null; deliveries are recorded as `failed` with
   `last_error_code = 'PUSH_PROVIDER_UNAVAILABLE'`). A real `onesignal` value
   slots in when credentials exist.

3. **MVP push events** are exactly check-in success and customer called
   (including recall) — realtime-queue §53. Near-turn stays deferred (ADR 0041).
   The outbox payload carries the push kind decided inside the mutating
   transaction (`push: 'checked_in' | 'called'`); the dispatcher never infers
   the transition from re-read state, so a stale row can't push a wrong event.

4. **Preference gate**: `user_notification_preferences.queue_updates = false`
   suppresses deliveries (no rows); the in-app `notifications` row is still
   created. A missing preferences row means all defaults (queue updates on).

5. **Recall rate limiting** (realtime-queue §54 "rate limit repeated recalls")
   is deferred — recall already requires a staff action per press.

## Consequences

- Local/dev/demo runs have a fully observable push pipeline (rows + logs)
  without any external provider account.
- Swapping in OneSignal later touches one factory + one new adapter file; the
  delivery bookkeeping and event mapping do not change.
- Rejected: creating deliveries from a separate notifications outbox consumer —
  one dispatcher already re-reads live state and owns retry/backoff; a second
  consumer would duplicate claim logic for no MVP gain.
