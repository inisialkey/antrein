# AntreIn — Flutter Frontend Brief

> **Document:** `docs/frontend/flutter-brief.md`  
> **Status:** Draft v1.0  
> **Product:** AntreIn  
> **Framework:** Flutter  
> **Platforms:** Android and iOS  
> **Architecture:** Feature-first pragmatic Clean Architecture  
> **State Management:** Cubit first, Bloc when justified  
> **Document Language:** English  
> **Last Updated:** 2026-07-21

---

## 1. Document Purpose

This document defines the implementation brief for the AntreIn Flutter application.

It translates product requirements, system architecture, API contracts, and backend behavior into mobile responsibilities, scope, quality expectations, delivery milestones, and acceptance criteria.

Read together with:

- `docs/00-product-brief.md`
- `docs/01-system-architecture.md`
- `docs/02-api-contract.md`
- `docs/frontend/app-architecture.md`
- `docs/frontend/navigation-flow.md`
- `docs/frontend/state-management.md`
- `docs/frontend/ui-feature-spec.md`

---

## 2. Mobile Mission

The Flutter application provides a clear, reliable, and role-aware user experience for:

- Customers booking and monitoring services.
- Business owners configuring operations.
- Staff managing bookings and queues.

Flutter owns presentation, interaction, local session handling, safe caching, and real-time synchronization.

Flutter does not own authoritative business correctness.

---

## 3. Product Roles

The application supports:

```text
customer
business_owner
staff
```

A single user may hold more than one role.

Platform administration is outside the mobile MVP.

---

## 4. Frontend Goals

The Flutter application must:

1. Provide a simple customer booking journey.
2. Provide a fast staff queue workflow.
3. Support role-aware navigation.
4. Handle REST, WebSocket, and push notifications consistently.
5. Recover safely from network failure.
6. Never infer payment success from a provider return.
7. Never generate authoritative queue or booking state.
8. Use secure token storage.
9. Keep feature boundaries maintainable.
10. Support Android and iOS.
11. Be testable with unit, widget, and integration tests.
12. Provide portfolio-quality architecture and UX without unnecessary abstraction.

---

## 5. Non-Goals

The mobile MVP does not include:

- Full web dashboard.
- Tablet-specific operations dashboard.
- Offline booking mutation.
- Background location tracking.
- Chat.
- Loyalty.
- Payroll.
- Inventory.
- Complex analytics.
- Multiple product languages.
- Native payment-card storage.
- Platform administration.
- Multi-window desktop support.

---

## 6. Recommended Technology Stack

```text
Flutter
Dart
flutter_bloc
Cubit
freezed
json_serializable
dio
go_router
get_it
flutter_secure_storage
sqflite or Drift for structured cache
shared_preferences only for non-sensitive preferences
web_socket_channel or Socket.IO-compatible Flutter client
OneSignal or provider adapter
cached_network_image
image_picker
flutter_image_compress
intl
connectivity_plus
```

The exact package selection must be pinned and reviewed during implementation.

---

## 7. Mobile Responsibilities

Flutter owns:

- UI rendering.
- Navigation.
- Form input.
- Client-side validation.
- Access-token attachment.
- Coordinated token refresh.
- Secure token persistence.
- Safe local cache.
- Role switching.
- Push registration.
- WebSocket connection.
- Loading, error, empty, and success states.
- Deep-link handling.
- Analytics events.
- Accessibility.
- Localization resources.

Flutter does not own:

- Final prices.
- Slot reservation.
- Booking confirmation.
- Payment verification.
- Queue-number generation.
- Queue ordering.
- Permission truth.
- Cancellation/refund calculation.

---

## 8. Application Modes

### Customer Mode

Primary tabs:

```text
Home
Bookings
Notifications
Profile
```

### Business Mode

Primary tabs:

```text
Dashboard
Bookings
Queue
Business
Profile
```

Staff may see a reduced subset based on permissions.

---

## 9. Core Customer Flow

```text
Launch
→ Authenticate
→ Browse businesses
→ View business
→ Select service
→ Select staff
→ Select date and slot
→ Review booking
→ Choose payment
→ Create booking
→ Complete payment when required
→ Wait for server confirmation
→ Check in
→ Monitor queue
→ Receive service
→ Submit review
```

---

## 10. Core Business Flow

```text
Authenticate
→ Select business role
→ Review dashboard
→ Manage services, staff, and schedule
→ Review bookings
→ Check in customers
→ Create walk-in
→ Operate queue
→ Start and complete services
→ Confirm pay-at-location payment
→ Review daily summary
```

---

## 11. Environment Strategy

Flutter configurations:

```text
local
development
staging
production
```

Environment controls:

- API base URL.
- WebSocket URL.
- Push provider application ID.
- Logging level.
- Analytics.
- Crash reporting.
- Feature flags.
- Payment return scheme.

Secrets must not be committed.

---

## 12. Session Behavior

Startup:

```text
Load secure token bundle
→ Validate expiration
→ Refresh if required
→ Fetch /me
→ Resolve roles
→ Restore last valid role
→ Enter role home
```

Refresh failure:

```text
Clear session
→ Disconnect WebSocket
→ Clear sensitive cache
→ Navigate to login
```

---

## 13. Network Behavior

Use one configured Dio client.

Responsibilities:

- Base URL.
- Authorization header.
- Request ID.
- App metadata.
- Timeout.
- Error parsing.
- Token refresh coordination.
- Redacted logs.

Automatic mutation retry is prohibited unless the request is idempotent.

---

## 14. Idempotency

Flutter generates stable keys for supported mutation attempts.

Examples:

```text
create booking
check in
cancel booking
confirm payment
queue command
refund request
```

A key remains stable while retrying the same logical action.

A changed user intent generates a new key.

---

## 15. Payment UX Rule

Returning from payment provider means:

```text
Checkout flow returned
```

It does not mean:

```text
Payment succeeded
```

Flutter must:

- Display pending state.
- Subscribe to payment updates.
- Fetch current payment state.
- Support manual refresh.
- Show success only after backend confirmation.

---

## 16. Real-Time Behavior

WebSocket is active for:

- Active booking.
- Active customer queue.
- Business queue dashboard.
- Notification updates.

After reconnect:

```text
Reauthenticate
→ Resubscribe
→ Fetch REST snapshot
→ Replace local state
```

---

## 17. Local Cache

Cacheable:

- User profile.
- Business list.
- Business detail.
- Services.
- Booking history.
- Notification history.
- Recent dashboard summary.

Always online:

- Slot availability.
- Booking creation.
- Payment confirmation.
- Check-in.
- Queue commands.
- Refund eligibility.

---

## 18. Error Experience

Every feature must support:

```text
initial
loading
success
empty
refreshing
failure
offline
```

Critical error examples:

- Slot unavailable.
- Session expired.
- Payment pending.
- Payment expired.
- Queue version conflict.
- Booking cancelled.
- Provider unavailable.

Stable backend error codes drive behavior.

---

## 19. Accessibility

Requirements:

- Semantic labels.
- Sufficient contrast.
- Minimum touch targets.
- Dynamic text tolerance.
- Status not represented only by color.
- Screen-reader friendly form labels.
- Large queue-number presentation.
- Clear error focus and announcement.

---

## 20. Localization

UI language:

```text
Bahasa Indonesia
```

Code and documentation:

```text
English
```

Formatting:

```text
Locale: id-ID
Currency: IDR
Timezone: outlet timezone, initially Asia/Jakarta
```

All visible strings use localization resources.

---

## 21. Analytics

Track only product-relevant events.

Examples:

```text
login_succeeded
business_viewed
service_selected
booking_created
payment_started
payment_succeeded
customer_checked_in
queue_called
service_completed
review_submitted
```

Do not send sensitive personal data.

---

## 22. Testing

Required:

- Unit tests for Cubits, repositories, mappers, and session logic.
- Widget tests for major screens.
- Integration tests for customer and staff flows.
- Contract tests for API parsing.
- Reconnect tests.
- Payment-resume tests.
- Golden tests for critical design-system components where valuable.

---

## 23. CI

Pipeline:

```text
flutter pub get
→ code generation
→ format check
→ analyze
→ unit tests
→ widget tests
→ contract compile check
→ integration test subset
→ Android build
```

iOS build may run on a macOS pipeline.

---

## 24. Delivery Milestones

### F0 — Foundation

- Flutter project.
- Environments.
- Theme.
- Localization.
- Router.
- Dependency injection.
- API client.
- Error model.

### F1 — Authentication

- Login.
- Registration.
- Secure session.
- Refresh coordination.
- Profile.
- Role resolution.

### F2 — Discovery

- Home.
- Business list.
- Search.
- Business detail.
- Service and staff display.

### F3 — Booking

- Service selection.
- Staff selection.
- Date/slot.
- Review.
- Create booking.
- Booking history/detail.

### F4 — Payment

- Payment-option selection.
- Checkout launch.
- Pending/success/failure states.
- App-resume recovery.
- Payment detail.

### F5 — Customer Queue

- Check-in.
- Live queue.
- Reconnect.
- Called state.
- Push deep link.

### F6 — Business Setup

- Business profile.
- Services.
- Staff.
- Operating hours.
- Closed dates.

### F7 — Business Operations

- Booking list.
- Queue dashboard.
- Walk-in.
- Queue commands.
- Pay-at-location confirmation.

### F8 — Review and Reports

- Review form.
- Daily summary.
- Notification center.

### F9 — Hardening

- Accessibility.
- Performance.
- Crash reporting.
- Analytics.
- Integration tests.
- Store-ready configuration.

---

## 25. Acceptance Criteria

The Flutter MVP is ready when:

- Authentication and refresh are reliable.
- Role-aware navigation works.
- Customer can complete booking end to end.
- Payment remains server-confirmed.
- Customer can check in and view live queue.
- Staff can manage queue safely.
- Network and session failures are recoverable.
- Push deep links open authorized resources.
- Sensitive tokens use secure storage.
- Backend error codes map to clear UX.
- Unit, widget, integration, and contract tests pass.
- Android and iOS builds succeed.

---

## 26. Final Frontend Statement

AntreIn Flutter is one role-aware mobile application.

Its responsibility model is:

```text
Flutter
→ Presents state
→ Captures intent
→ Calls REST
→ Observes WebSocket
→ Stores safe local cache
→ Recovers through REST
```

Its core guarantee is:

```text
The application remains responsive and understandable
without becoming the source of truth for booking,
payment, authorization, or queue correctness.
```
