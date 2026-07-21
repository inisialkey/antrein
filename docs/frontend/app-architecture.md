# AntreIn — Flutter App Architecture

> **Document:** `docs/frontend/app-architecture.md`  
> **Status:** Draft v1.0  
> **Framework:** Flutter  
> **Architecture:** Feature-first pragmatic Clean Architecture  
> **Document Language:** English  
> **Last Updated:** 2026-07-21

---

## 1. Purpose

This document defines the internal architecture of the AntreIn Flutter application.

It covers:

- Project structure.
- Layers.
- Dependency direction.
- Core services.
- API integration.
- Local cache.
- Session management.
- WebSocket integration.
- Push notification handling.
- Code generation.
- Testing boundaries.
- Performance and security conventions.

---

## 2. Architecture Goals

The application architecture must:

1. Keep features isolated.
2. Avoid global mutable feature state.
3. Support customer and business modes.
4. Keep transport models out of UI.
5. Support generated API contracts.
6. Make session refresh centralized.
7. Make real-time recovery predictable.
8. Keep tests fast.
9. Avoid unnecessary boilerplate.
10. Allow features to evolve independently.

---

## 3. Top-Level Structure

```text
apps/mobile/lib/
├── main.dart
├── bootstrap.dart
├── app/
│   ├── app.dart
│   ├── environment/
│   ├── router/
│   ├── theme/
│   ├── localization/
│   └── role/
├── core/
│   ├── analytics/
│   ├── auth/
│   ├── cache/
│   ├── config/
│   ├── database/
│   ├── deep_link/
│   ├── error/
│   ├── logging/
│   ├── network/
│   ├── notification/
│   ├── realtime/
│   ├── security/
│   ├── utils/
│   └── widgets/
└── features/
    ├── authentication/
    ├── profile/
    ├── discovery/
    ├── business_detail/
    ├── booking/
    ├── payment/
    ├── customer_queue/
    ├── notifications/
    ├── reviews/
    ├── business_dashboard/
    ├── business_management/
    ├── service_management/
    ├── staff_management/
    ├── schedule_management/
    ├── business_bookings/
    ├── business_queue/
    └── reports/
```

---

## 4. Feature Structure

```text
features/booking/
├── data/
│   ├── datasources/
│   ├── models/
│   ├── mappers/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── cubit/
    ├── pages/
    └── widgets/
```

Small features may omit one-line use cases.

The dependency rule matters more than folder count.

---

## 5. Dependency Direction

```text
Presentation
→ Domain

Data
→ Domain

App
→ Feature public APIs and Core
```

Forbidden:

```text
Domain → Flutter widgets
Domain → Dio
Domain → sqflite
Presentation → Dio
Presentation → generated API implementation
Feature A → internal files of Feature B
```

---

## 6. Presentation Layer

Owns:

- Pages.
- Widgets.
- Cubits.
- View models when needed.
- Form controllers.
- Navigation intent.
- UI formatting.

Does not own:

- API calls.
- Token storage.
- Database queries.
- Authoritative business calculations.

---

## 7. Domain Layer

Owns:

- Feature entities.
- Repository interfaces.
- Use cases.
- Client-safe domain concepts.
- Typed outcomes.

Domain entities are optimized for mobile behavior, not database shape.

---

## 8. Data Layer

Owns:

- Remote data sources.
- Local data sources.
- Repository implementations.
- Generated API mapping.
- Cache strategy.
- Error translation.

---

## 9. Core Layer

Core contains reusable infrastructure only.

Examples:

- `ApiClient`
- `SessionManager`
- `RealtimeClient`
- `SecureTokenStorage`
- `AppDatabase`
- `AppFailure`
- `RequestIdGenerator`
- `AppLogger`

Core must not contain booking-specific logic.

---

## 10. Dependency Injection

Use GetIt.

Registration categories:

```text
Singleton:
- Environment
- Dio
- AppDatabase
- SecureTokenStorage
- SessionManager
- RealtimeClient

Lazy singleton:
- Repositories
- Shared services

Factory:
- Cubits
- Form coordinators
```

Feature registration should be grouped by module.

---

## 11. Bootstrap Sequence

```text
Initialize Flutter bindings
→ Load environment
→ Initialize logging
→ Initialize secure storage
→ Initialize database
→ Register dependencies
→ Initialize notification provider
→ Create application
→ Restore session asynchronously
```

Startup failures must display a recoverable initialization screen.

---

## 12. Environment Model

```dart
enum AppEnvironment {
  local,
  development,
  staging,
  production,
}
```

Environment config includes:

- API URL.
- WebSocket URL.
- Push provider ID.
- Logging.
- Analytics.
- Crash reporting.
- Feature flags.

---

## 13. API Client

Dio configuration:

- JSON.
- Timeouts.
- Access-token interceptor.
- Request ID.
- App version/platform headers.
- Refresh interceptor.
- Error parser.
- Redacted logging.

Generated API methods may wrap Dio but must remain behind repositories.

---

## 14. Generated API Client

Recommended location:

```text
lib/core/network/generated/
```

Rules:

- Never edit manually.
- Never use generated DTOs directly in screens.
- Map into domain entities.
- Regenerate on contract changes.
- Compile in CI.

---

## 15. Error Model

Base:

```dart
sealed class AppFailure {
  const AppFailure({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}
```

Categories:

```text
NetworkFailure
AuthenticationFailure
AuthorizationFailure
ValidationFailure
ConflictFailure
PaymentFailure
QueueFailure
ServerFailure
UnknownFailure
```

Stable API codes remain available to Cubits.

---

## 16. Repository Result

Use one consistent approach:

```dart
Future<Result<T, AppFailure>>
```

or:

```dart
Future<Either<AppFailure, T>>
```

The project should not mix result styles.

---

## 17. Session Architecture

Components:

```text
SecureTokenStorage
InMemoryTokenManager
SessionRepository
SessionCubit
AuthInterceptor
RefreshCoordinator
```

Token reads should usually come from memory after bootstrap.

---

## 18. Refresh Coordinator

One refresh operation at a time.

```text
401
→ Check endpoint eligibility
→ Await existing refresh or start refresh
→ Save new token bundle
→ Replay safe request once
```

Refresh failure emits session expiration.

---

## 19. Local Database

Use sqflite or Drift for:

- Notification history cache.
- Business cache.
- Booking summaries.
- Pending local UI metadata.
- Analytics queue if required.

Do not store raw authentication tokens.

---

## 20. Cache Policy

Every cached record should define:

- Key.
- Timestamp.
- Owner/user scope.
- Role scope.
- TTL or stale behavior.
- Clear-on-logout behavior.

Sensitive business data must be cleared when switching user.

---

## 21. Realtime Client

Responsibilities:

- Connect/disconnect.
- Authenticate.
- Resubscribe.
- Parse event envelope.
- Expose typed event stream.
- Reconnect with backoff.
- Deduplicate event IDs where practical.
- Report connection state.

Does not own feature state.

---

## 22. Realtime Event Routing

```text
RealtimeClient
→ RealtimeEventRouter
→ Feature subscription
→ Feature Cubit
```

A feature subscribes only while relevant.

Examples:

- Payment detail subscribes to payment events.
- Customer queue subscribes to queue entry.
- Business queue subscribes to outlet queue.

---

## 23. Push Notification Architecture

Responsibilities:

- Request permission.
- Register device token.
- Handle foreground notification.
- Handle notification tap.
- Route deep link.
- Persist in-app notification through API/cache.

Push payload identifies a resource, not full authoritative state.

---

## 24. Deep Links

Examples:

```text
antrein://bookings/{bookingId}
antrein://payments/{paymentId}
antrein://queue/{bookingId}
```

Deep-link handler:

```text
Parse
→ Restore session
→ Validate route access through API
→ Navigate
```

---

## 25. Role Context

Central role context:

```text
customer
business
```

Business context includes:

- Business ID.
- Outlet ID.
- Membership role.
- Permissions.

Role switch clears role-scoped feature states and subscriptions.

---

## 26. Feature Public API

Cross-feature dependency should use a public barrel or coordinator.

Example:

```text
features/booking/booking.dart
```

Avoid importing another feature’s internal Cubit or data source.

---

## 27. Shared UI

Shared widgets:

- App scaffold.
- Loading view.
- Error view.
- Empty view.
- Money text.
- Status chip.
- Primary button.
- Form field.
- Async action button.
- Confirmation sheet.
- Network banner.

Do not create a generic widget before two real use cases exist.

---

## 28. Theme

Use Material 3 with:

- Seeded `ColorScheme`.
- Theme extensions for semantic colors.
- Typography scale.
- Spacing tokens.
- Radius tokens.
- Elevation tokens.

Status colors live in semantic theme extensions.

---

## 29. Localization

Use Flutter localization generation.

Keys use semantic English names:

```text
bookingCreateTitle
paymentPendingMessage
queueCalledTitle
```

Do not use visible Indonesian text as localization keys.

---

## 30. Logging

Debug logs may include:

- Request ID.
- Endpoint.
- Status.
- Duration.
- Error code.

Never include:

- Tokens.
- Passwords.
- Push token.
- Payment checkout secret.
- Full personal data.

---

## 31. Analytics

Analytics wrapper prevents provider coupling.

```dart
abstract interface class AnalyticsService {
  Future<void> track(
    String event, {
    Map<String, Object?> parameters,
  });
}
```

---

## 32. Testing Boundaries

Unit tests:

- Cubits.
- Use cases.
- Mappers.
- Repositories with fake data sources.
- Refresh coordinator.
- Realtime reducers.

Widget tests:

- Pages with mocked Cubits/repositories.
- Error and empty states.
- Role navigation.

Integration tests:

- Real router.
- Fake backend or controlled environment.
- Payment resume.
- Reconnect.

---

## 33. Performance

Rules:

- Paginate lists.
- Avoid unnecessary rebuilds.
- Use selectors where useful.
- Compress uploads.
- Cache image thumbnails.
- Avoid loading full queue history.
- Dispose streams/controllers.
- Profile before optimization.

---

## 34. Security

- Secure token storage.
- Clear sensitive cache on logout.
- Redact logs.
- Validate deep links.
- Do not trust local permissions.
- Do not show cached private data before session ownership is resolved.
- Avoid screenshots on sensitive screens only if product requires it.

---

## 35. Architecture Acceptance Criteria

- Feature boundaries exist.
- Presentation does not call Dio.
- Generated models do not leak into UI.
- Session refresh is centralized.
- Realtime client is feature-independent.
- Role switching clears scope.
- Cache is user-scoped.
- Errors use stable codes.
- Tests cover critical infrastructure.
- Architecture remains understandable without excessive boilerplate.
