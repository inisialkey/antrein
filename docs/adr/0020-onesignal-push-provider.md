# ADR 0020 — Push notifications: OneSignal

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

Docs lean OneSignal throughout (`PUSH_PROVIDER=onesignal` in env examples, `pushProvider: "onesignal"` in the device-registration contract) while listing the provider as open.

## Decision

OneSignal, behind `PushNotificationPort` (`OneSignalPushAdapter`). Device tokens registered via `PUT /me/devices/{deviceId}`; delivery driven by the outbox worker; invalid tokens mark the device `invalid`.

## Consequences

- Matches all documented payloads — no contract changes.
- FCM/APNs credentials managed inside OneSignal; a direct-FCM adapter remains possible later via the port.
