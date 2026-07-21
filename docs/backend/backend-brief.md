# AntreIn — Backend Brief

> **Document:** `docs/backend/backend-brief.md`  
> **Status:** Draft v1.0  
> **Product:** AntreIn  
> **Backend Framework:** NestJS  
> **Primary Database:** PostgreSQL  
> **ORM:** Prisma  
> **Architecture Style:** Modular Monolith  
> **Repository Strategy:** Monorepo  
> **Document Language:** English  
> **Last Updated:** 2026-07-21

---

## 1. Document Purpose

This document defines the implementation brief for the AntreIn backend.

It translates the product requirements, system architecture, and API contract into backend-specific responsibilities, boundaries, implementation rules, delivery milestones, testing expectations, security controls, and operational requirements.

It must be read together with:

- `docs/00-product-brief.md`
- `docs/01-system-architecture.md`
- `docs/02-api-contract.md`
- `docs/backend/database-design.md`
- `docs/backend/authentication.md`
- `docs/backend/booking-payment.md`
- `docs/backend/realtime-queue.md`

This document answers:

- What must the backend own?
- How should the NestJS application be structured?
- How should modules communicate?
- Which operations require transactions?
- How should payment, queue, notification, and file providers be integrated?
- What must be tested before a feature is considered complete?
- How should the backend be deployed and observed?

---

## 2. Backend Mission

The backend exists to protect product correctness.

Its primary responsibilities are:

- Authenticate users.
- Authorize actions.
- Validate business rules.
- Store durable state.
- Prevent invalid transitions.
- Prevent duplicate effects.
- Coordinate external providers.
- Publish real-time changes.
- Deliver notifications asynchronously.
- Expose a stable API contract to Flutter.
- Produce auditable operational history.

The backend must never delegate critical correctness to Flutter.

---

## 3. Backend Goals

The backend must:

1. Be understandable and maintainable by a solo developer.
2. Keep domain responsibilities separated.
3. Support end-to-end vertical slices.
4. Use PostgreSQL as the durable source of truth.
5. Handle concurrent requests safely.
6. Keep external-provider logic behind adapters.
7. Produce stable OpenAPI documentation.
8. Support unit, integration, concurrency, and end-to-end testing.
9. Run locally through Docker-based infrastructure.
10. Be observable in development, staging, and production.
11. Avoid premature microservice complexity.
12. Remain compatible with the Flutter client contract.
13. Recover safely from network and provider failures.
14. Preserve business history and auditability.

---

## 4. Non-Goals

The backend MVP does not include:

- Microservices.
- Event sourcing.
- Distributed transactions.
- Kafka.
- Kubernetes.
- Service mesh.
- GraphQL.
- Multi-region deployment.
- Multi-currency.
- Marketplace settlement.
- Full accounting.
- Business subscription billing.
- Payroll.
- Inventory.
- Loyalty.
- Chat.
- Advanced recommendation systems.
- Data warehouse.
- Complex CQRS infrastructure.

---

## 5. Technology Stack

### Core

```text
Node.js
TypeScript
NestJS
PostgreSQL
Prisma
```

### Supporting Infrastructure

```text
Redis
Docker
Docker Compose
S3-compatible object storage
OpenAPI / Swagger
Socket.IO-compatible WebSocket transport
```

### Testing

```text
Jest
Supertest
PostgreSQL integration-test database
Testcontainers or Docker-based test dependencies
```

### Observability

```text
Structured JSON logging
Error tracking
Health checks
Metrics
Optional OpenTelemetry
```

### Quality Tooling

```text
ESLint
Prettier
TypeScript strict mode
Dependency audit
Container scanning
Migration validation
```

---

## 6. Architectural Style

The backend uses a **modular monolith**.

One deployable application contains domain-oriented modules:

```text
NestJS Application
├── Authentication
├── Users
├── Businesses
├── Outlets
├── Memberships
├── Services
├── Staff
├── Schedules
├── Bookings
├── Payments
├── Queues
├── Notifications
├── Reviews
├── Reports
├── Files
├── Audit
└── Administration
```

Each module owns its business rules and public application interface.

Modules must not become arbitrary folders around database tables.

---

## 7. Project Structure

```text
apps/api/
├── src/
│   ├── main.ts
│   ├── app.module.ts
│   │
│   ├── config/
│   │   ├── app.config.ts
│   │   ├── auth.config.ts
│   │   ├── database.config.ts
│   │   ├── redis.config.ts
│   │   ├── storage.config.ts
│   │   ├── payment.config.ts
│   │   ├── notification.config.ts
│   │   └── validation.schema.ts
│   │
│   ├── common/
│   │   ├── auth/
│   │   ├── decorators/
│   │   ├── errors/
│   │   ├── filters/
│   │   ├── guards/
│   │   ├── interceptors/
│   │   ├── logging/
│   │   ├── pagination/
│   │   ├── pipes/
│   │   ├── presenters/
│   │   ├── serialization/
│   │   ├── validation/
│   │   └── utils/
│   │
│   ├── infrastructure/
│   │   ├── database/
│   │   ├── cache/
│   │   ├── storage/
│   │   ├── payments/
│   │   ├── notifications/
│   │   ├── realtime/
│   │   ├── jobs/
│   │   └── observability/
│   │
│   └── modules/
│       ├── auth/
│       ├── users/
│       ├── businesses/
│       ├── outlets/
│       ├── memberships/
│       ├── services/
│       ├── staff/
│       ├── schedules/
│       ├── bookings/
│       ├── payments/
│       ├── queues/
│       ├── notifications/
│       ├── reviews/
│       ├── reports/
│       ├── files/
│       ├── audit/
│       └── admin/
│
├── prisma/
│   ├── schema.prisma
│   ├── migrations/
│   └── seed/
│
├── test/
│   ├── fixtures/
│   ├── factories/
│   ├── helpers/
│   ├── integration/
│   └── e2e/
│
├── Dockerfile
├── nest-cli.json
├── package.json
├── tsconfig.json
└── tsconfig.build.json
```

---

## 8. Module Internal Structure

Complex modules should use:

```text
modules/bookings/
├── domain/
│   ├── entities/
│   ├── value-objects/
│   ├── policies/
│   ├── events/
│   ├── repositories/
│   └── errors/
│
├── application/
│   ├── commands/
│   ├── queries/
│   ├── use-cases/
│   ├── dto/
│   ├── mappers/
│   └── ports/
│
├── infrastructure/
│   ├── persistence/
│   ├── repositories/
│   └── mappers/
│
├── presentation/
│   ├── controllers/
│   ├── presenters/
│   └── swagger/
│
├── booking.constants.ts
└── booking.module.ts
```

Small modules may use a flatter layout.

The required outcome is clear responsibility separation, not maximum folder depth.

---

## 9. Layer Responsibilities

### 9.1 Presentation Layer

Responsible for:

- HTTP controllers.
- WebSocket gateways.
- Request DTO validation.
- Authentication-context extraction.
- Response presentation.
- OpenAPI decorators.
- Mapping application errors into API responses.

Must not:

- Query Prisma directly.
- Calculate prices.
- Decide permissions.
- Perform state transitions.
- Call payment providers directly.

### 9.2 Application Layer

Responsible for:

- Commands.
- Queries.
- Use cases.
- Transaction orchestration.
- Cross-module coordination.
- Idempotency orchestration.
- Publishing domain or outbox events.
- Calling infrastructure ports.

### 9.3 Domain Layer

Responsible for:

- Invariants.
- Status-transition policies.
- Value objects.
- Domain errors.
- Domain events.
- Framework-independent rules where practical.

### 9.4 Infrastructure Layer

Responsible for:

- Prisma repositories.
- Redis integration.
- Object storage.
- Payment adapters.
- Push adapters.
- WebSocket transport.
- Worker execution.
- Logging and observability integration.

---

## 10. Dependency Rules

Allowed direction:

```text
Presentation
→ Application
→ Domain

Infrastructure
→ Application ports
Infrastructure
→ Domain repository interfaces
```

Forbidden:

```text
Domain → NestJS
Domain → Prisma
Domain → Socket.IO
Domain → Payment SDK
Controller → Prisma
Controller → External provider SDK
```

Cross-module calls use public application services or explicit ports.

---

## 11. Shared Infrastructure

Shared infrastructure includes:

- Configuration.
- Database connection.
- Transaction helper.
- Logging.
- Error mapping.
- Request IDs.
- Authentication guards.
- Authorization policies.
- Pagination.
- Idempotency.
- Outbox.
- Health checks.
- Provider adapters.

Shared infrastructure must not become a dumping ground for domain-specific logic.

---

## 12. Application Bootstrap

Startup sequence:

```text
Load environment
→ Validate configuration
→ Initialize logger
→ Initialize NestJS application
→ Configure global validation
→ Configure global exception filter
→ Configure request IDs
→ Configure response envelope
→ Configure API prefix
→ Configure OpenAPI
→ Initialize database
→ Initialize Redis when enabled
→ Start HTTP server
→ Start worker process or worker loop
```

The application must fail fast when required configuration is missing or invalid.

---

## 13. Global API Configuration

Required:

```text
Global prefix: /api/v1
JSON body parsing
Raw body access for payment webhooks
CORS configuration
Request-size limits
Validation pipe
Response serialization
Global exception filter
Request-ID middleware or interceptor
Structured logging
```

The payment-webhook path must preserve the raw request body when required by provider signature verification.

---

## 14. Configuration

Environment groups:

```text
APP
DATABASE
REDIS
AUTH
STORAGE
PAYMENT
NOTIFICATION
OBSERVABILITY
RATE_LIMIT
FILE_UPLOAD
```

Example `.env.example`:

```dotenv
NODE_ENV=development
PORT=3000
API_PREFIX=/api/v1

DATABASE_URL=postgresql://postgres:postgres@localhost:5432/antrein
REDIS_URL=redis://localhost:6379

ACCESS_TOKEN_TTL_MINUTES=15
REFRESH_TOKEN_TTL_DAYS=30
JWT_ACCESS_SECRET=replace-me
JWT_REFRESH_SECRET=replace-me

STORAGE_ENDPOINT=http://localhost:9000
STORAGE_BUCKET=antrein
STORAGE_ACCESS_KEY=replace-me
STORAGE_SECRET_KEY=replace-me

PAYMENT_PROVIDER=sandbox
PAYMENT_WEBHOOK_SECRET=replace-me

PUSH_PROVIDER=onesignal
PUSH_APP_ID=replace-me
PUSH_API_KEY=replace-me
```

Production secrets must come from protected deployment configuration or a secret manager.

---

## 15. Data Ownership

PostgreSQL owns all durable business state.

Redis is not authoritative for:

- Bookings.
- Payments.
- Refunds.
- Queue history.
- Authentication sessions.
- Business configuration.
- Audit history.

Object storage owns file binaries.

PostgreSQL owns file metadata and attachment relationships.

---

## 16. Prisma Strategy

Prisma is used for:

- Schema definition.
- Migration generation.
- Typed queries.
- Transactions.
- Repository implementation.

Prisma models are persistence models, not public API models.

Raw Prisma records must not be returned by controllers.

---

## 17. Database Transaction Policy

A transaction is required when one business action changes multiple related records or enforces a concurrency-sensitive invariant.

Required transaction examples:

- Register user and initial session.
- Rotate refresh token.
- Create business and owner membership.
- Create booking and booking history.
- Process payment webhook.
- Cancel booking and create refund request.
- Check in and create queue entry.
- Generate queue number.
- Call queue entry and update booking.
- Complete service and update booking.
- Confirm pay-at-location payment.
- Reorder queue.
- Claim outbox event.
- Apply idempotency result.

Simple reads do not require transactions.

---

## 18. Transaction Boundaries

A transaction should:

- Be short.
- Avoid network calls.
- Avoid push-provider calls.
- Avoid object-storage uploads.
- Avoid unnecessary locks.
- Persist outbox events rather than delivering inside the transaction.

External provider interaction must use an explicit orchestration strategy with recoverable local state.

---

## 19. Concurrency Control

Critical concurrency areas:

- Booking overlap.
- Queue-number generation.
- Check-in duplication.
- Payment-webhook duplication.
- Refund duplication.
- Queue commands.
- Refresh-token rotation.
- Idempotency-key reuse.

Protection mechanisms:

- Unique constraints.
- Transactions.
- Row locking.
- Version columns.
- Atomic updates.
- Request fingerprints.
- Conflict mapping.
- Concurrent integration tests.

---

## 20. Idempotency Module

The idempotency module should expose a reusable application service such as:

```text
executeIdempotently(context, handler)
```

Context includes:

- User or provider scope.
- Endpoint action.
- Idempotency key.
- Request fingerprint.
- Retention period.

Suggested states:

```text
processing
succeeded
failed_retryable
failed_final
```

Behavior:

- Same key and same payload returns the original result.
- Same key and different payload returns a conflict.
- Concurrent duplicate requests do not execute twice.
- Provider webhook event IDs use durable uniqueness.

---

## 21. Response Envelope

Application endpoints follow `docs/02-api-contract.md`.

Success:

```json
{
  "success": true,
  "data": {},
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Error:

```json
{
  "success": false,
  "error": {
    "code": "BOOKING_SLOT_UNAVAILABLE",
    "message": "The selected time slot is no longer available.",
    "details": {}
  },
  "meta": {
    "requestId": "req_01J...",
    "timestamp": "2026-07-21T13:30:00+07:00"
  }
}
```

Provider webhooks may use provider-specific responses.

---

## 22. Error Model

Backend errors use typed application errors.

Example concept:

```ts
class ApplicationError extends Error {
  code: string;
  httpStatus: number;
  details?: Record<string, unknown>;
  cause?: unknown;
}
```

Error categories:

```text
Authentication
Authorization
Validation
Business
Booking
Payment
Queue
File
Rate limit
System
```

Database and provider exceptions must be mapped before reaching the client.

---

## 23. Error-Mapping Rules

Examples:

```text
Unique booking conflict
→ BOOKING_SLOT_UNAVAILABLE
→ HTTP 409

Invalid payment transition
→ PAYMENT_ALREADY_PROCESSED
→ HTTP 409

Unauthorized business access
→ FORBIDDEN_BUSINESS_RESOURCE
→ HTTP 403

Provider timeout
→ PAYMENT_PROVIDER_UNAVAILABLE
→ HTTP 502 or 503
```

Raw Prisma and PostgreSQL messages must never become client messages.

---

## 24. Authentication Module

The authentication module owns:

- Registration.
- Login.
- Access-token issuance.
- Refresh-token rotation.
- Logout.
- Session revocation.
- Password reset.
- Authentication guards.
- Current-user context.

Detailed rules belong in `docs/backend/authentication.md`.

---

## 25. Access Tokens

Access tokens should:

- Be short-lived.
- Contain minimal claims.
- Include user ID.
- Include session ID.
- Avoid embedding long-lived mutable permission lists.
- Be accepted by REST and WebSocket authentication.

Current membership and ownership still require server-side validation.

---

## 26. Refresh Sessions

Refresh sessions should store:

- Session ID.
- User ID.
- Device ID.
- Refresh-token hash.
- Issued time.
- Expiration.
- Revocation state.
- Rotation-chain metadata.
- Last-used timestamp.
- Device metadata.

Refresh-token reuse should revoke the affected session family.

---

## 27. Password Security

Requirements:

- Use Argon2id or another modern password-hashing algorithm.
- Enforce minimum length.
- Never log passwords.
- Reset tokens are single-use.
- Reset tokens expire.
- Password reset revokes relevant sessions.
- Login and recovery endpoints are rate-limited.

---

## 28. Authorization

Authorization combines:

- Authentication.
- User state.
- Business membership.
- Permission.
- Outlet assignment.
- Resource ownership.
- Resource status.
- Action policy.

Recommended components:

```text
@Public()
@RequirePermissions(...)
CurrentUser decorator
BusinessMembershipGuard
ResourceOwnershipPolicy
OutletScopePolicy
```

A global authentication guard should protect routes by default.

---

## 29. Permission Model

Recommended permissions:

```text
business.read
business.manage
service.read
service.manage
staff.read
staff.manage
schedule.read
schedule.manage
booking.read
booking.manage
queue.read
queue.manage
queue.reorder
payment.read
payment.confirm
payment.refund
reports.read
review.moderate
```

Permissions are always evaluated with business and outlet scope.

---

## 30. User Module

The user module owns:

- User profile.
- Contact details.
- Avatar reference.
- User status.
- Notification preferences.
- Account-deletion workflow.
- Device ownership relationship.

---

## 31. Business Module

The business module owns:

- Business profile.
- Verification state.
- Branding.
- Booking policy.
- Cancellation policy.
- Payment-option configuration.
- Default timezone.
- Owner relationship.

---

## 32. Outlet Module

The outlet module owns:

- Outlet identity.
- Address.
- Coordinates.
- Phone number.
- Timezone.
- Active state.
- Queue configuration.
- Public opening state.

MVP supports one outlet while preserving a future multi-outlet model.

---

## 33. Membership Module

The membership module owns:

- Owner membership.
- Staff membership.
- Invitation lifecycle.
- Permissions.
- Outlet assignment.
- Membership state.
- Role display.

Invitation flow must prevent duplicate active membership and duplicate pending invitations.

---

## 34. Service Module

The service module owns:

- Name.
- Description.
- Image.
- Duration.
- Price.
- Deposit policy.
- Active state.
- Eligible staff.

Rules:

- Price uses integer IDR units.
- Duration is positive.
- Percentage deposit stays within the allowed range.
- Historical bookings use snapshots.
- Deactivation does not remove historical references.

---

## 35. Staff Module

The staff module owns:

- Staff display profile.
- Membership connection.
- Role.
- Service eligibility.
- Outlet assignment.
- Active state.

Rules:

- Staff belongs to the business.
- Eligible services belong to the same business.
- Staff identity and user identity remain separate concepts.
- Deactivation behavior with future bookings follows explicit policy.

---

## 36. Schedule Module

The schedule module owns:

- Outlet operating hours.
- Staff working hours.
- Break periods.
- Closed dates.
- Lead time.
- Booking horizon.
- Slot generation.
- Slot validation.

Availability is derived data.

The MVP does not persist every possible slot.

---

## 37. Slot Generation

Inputs:

- Outlet timezone.
- Business date.
- Service duration.
- Outlet hours.
- Staff hours.
- Breaks.
- Closed dates.
- Existing active bookings.
- Lead time.
- Booking horizon.

Output:

- Candidate start time.
- Candidate end time.
- Availability flag.
- Staff eligibility.

Booking creation always revalidates availability.

---

## 38. Booking Module

The booking module owns:

- Booking creation.
- Booking code.
- Booking type.
- Booking snapshots.
- Booking lifecycle.
- Customer ownership.
- Staff assignment.
- Cancellation.
- Check-in eligibility.
- No-show.
- Booking history.
- Business booking queries.

Detailed rules belong in `docs/backend/booking-payment.md`.

---

## 39. Booking Status Machine

Allowed transitions:

```text
draft → pending_payment
draft → confirmed
pending_payment → confirmed
pending_payment → expired
pending_payment → cancelled
confirmed → checked_in
confirmed → cancelled
confirmed → no_show
checked_in → waiting
waiting → called
called → in_service
called → skipped
called → no_show
skipped → waiting
in_service → completed
```

Transition enforcement must be centralized.

---

## 40. Booking Snapshot

A booking snapshot stores:

- Service ID.
- Service name.
- Service duration.
- Service price.
- Deposit policy.
- Assigned staff identity.
- Outlet details needed for history.
- Currency.
- Relevant policy summary or version.

Historical totals must not change when service configuration changes.

---

## 41. Booking Conflict Prevention

Application validation:

- Staff is active.
- Service is active.
- Staff is eligible.
- Schedule is valid.
- No known overlap exists.

Database guarantee:

- Constraint or transaction-safe overlap strategy.
- Conflict mapping.
- Concurrent integration tests.

The exact PostgreSQL implementation belongs in `database-design.md`.

---

## 42. Booking Creation Flow

```text
Authenticate customer
→ Validate request
→ Validate business, outlet, service, and staff
→ Calculate authoritative price
→ Calculate payment requirement
→ Validate availability
→ Begin transaction
→ Check idempotency
→ Create booking and snapshot
→ Create status history
→ Create local payment record when required
→ Insert outbox event
→ Commit
→ Create provider payment when required
→ Persist provider result
→ Return response
```

Provider-call ordering must be implemented with explicit recovery behavior.

---

## 43. Booking Cancellation

Cancellation must:

- Verify ownership or business permission.
- Verify current status.
- Evaluate cancellation window.
- Calculate refund eligibility.
- Update booking.
- Cancel queue entry when applicable.
- Create refund request when required.
- Write history and audit records.
- Publish outbox events.

---

## 44. Payment Module

The payment module owns:

- Payment intent.
- Provider reference.
- Amount.
- Currency.
- Payment option.
- Payment status.
- Expiration.
- Provider events.
- Refunds.
- Pay-at-location records.
- Reconciliation.

Provider details remain behind an adapter.

---

## 45. Payment Provider Port

```ts
interface PaymentProviderPort {
  createPayment(input: CreatePaymentInput): Promise<CreatePaymentResult>;
  getPaymentStatus(input: GetPaymentStatusInput): Promise<PaymentStatusResult>;
  cancelPayment(input: CancelPaymentInput): Promise<CancelPaymentResult>;
  requestRefund(input: RequestRefundInput): Promise<RefundResult>;
  verifyWebhook(input: VerifyWebhookInput): Promise<boolean>;
  parseWebhook(input: ParseWebhookInput): Promise<ParsedPaymentEvent>;
}
```

The interface represents AntreIn requirements rather than mirroring one provider SDK.

---

## 46. Payment Webhook

Webhook processing must:

1. Preserve raw body if required.
2. Verify signature.
3. Resolve provider event ID.
4. Begin transaction.
5. Detect duplicate event.
6. Store event.
7. Validate provider reference.
8. Validate amount and currency.
9. Validate payment transition.
10. Update payment.
11. Update booking when required.
12. Insert history.
13. Insert outbox events.
14. Commit.
15. Return provider-compatible acknowledgement.

Notification delivery is asynchronous.

---

## 47. Pay-at-Location

Pay-at-location confirmation requires:

- Authenticated staff.
- `payment.confirm` permission.
- Correct business.
- Correct outlet where required.
- Exact amount validation.
- Currency validation.
- Idempotency.
- Audit log.
- Payment-history record.

---

## 48. Refunds

Refund rules:

- Refund amount cannot exceed net paid amount.
- Duplicate refund requests are prevented.
- Provider refunds may be asynchronous.
- Refund status is persisted.
- Webhook or reconciliation updates final state.
- Manual adjustment requires permission and audit.

---

## 49. Queue Module

The queue module owns:

- Queue entry.
- Daily queue number.
- Display number.
- Queue state.
- Ordering.
- Call.
- Recall.
- Skip.
- Return to waiting.
- Start service.
- Complete service.
- No-show.
- Queue version.
- Queue snapshots.

Detailed rules belong in `docs/backend/realtime-queue.md`.

---

## 50. Queue Status Machine

Allowed transitions:

```text
waiting → called
called → skipped
called → in_service
called → no_show
skipped → waiting
in_service → completed
waiting → cancelled
called → cancelled
```

Queue and booking transitions must be coordinated transactionally.

---

## 51. Queue Number Generation

Required guarantee:

```text
UNIQUE(outlet_id, business_date, queue_number)
```

Recommended flow:

```text
Begin transaction
→ Lock or atomically update daily counter
→ Increment counter
→ Create queue entry
→ Commit
```

Client-provided queue numbers are rejected or ignored.

---

## 52. Queue Versioning

Queue resources use a version number for:

- Staff action conflict detection.
- Queue reorder conflict detection.
- Stale WebSocket event protection.
- Client reconciliation.

Commands may include:

```json
{
  "expectedVersion": 5
}
```

Mismatch returns:

```text
QUEUE_VERSION_CONFLICT
```

---

## 53. Notification Module

The notification module owns:

- Notification records.
- Templates.
- User preferences.
- Device targeting.
- Delivery attempts.
- Retry.
- Invalid-device handling.
- In-app history.

Push notification is not authoritative state.

---

## 54. Notification Outbox

A business transaction writes:

```text
Notification intent
+ Outbox event
```

Worker responsibilities:

- Claim event.
- Build localized content.
- Resolve active devices.
- Call provider.
- Store delivery result.
- Retry transient failures.
- Disable invalid tokens.

---

## 55. Push Provider Port

```ts
interface PushNotificationPort {
  sendToDevices(input: SendPushInput): Promise<SendPushResult>;
  removeInvalidDevice(input: RemoveInvalidDeviceInput): Promise<void>;
}
```

The initial provider may be OneSignal.

Domain and application code must not depend on OneSignal-specific types.

---

## 56. WebSocket Gateway

The gateway owns transport concerns:

- Authentication.
- Connection lifecycle.
- Subscription requests.
- Room membership.
- Event serialization.
- Disconnect handling.

The gateway does not own queue business rules.

---

## 57. Real-Time Publication

```text
Business transaction commits
→ Outbox worker reads event
→ Realtime publisher resolves audience
→ WebSocket event is published
→ Push notification may also be sent
```

Public events are versioned:

```text
booking.updated.v1
payment.updated.v1
queue.entry.updated.v1
queue.snapshot.updated.v1
notification.created.v1
```

---

## 58. Redis

Redis may be used for:

- Socket.IO adapter.
- Rate-limit counters.
- Short-lived cache.
- Ephemeral presence.
- Worker coordination.
- Temporary locks.

Redis failure must not corrupt durable business state.

---

## 59. File Module

The file module owns:

- Upload validation.
- File metadata.
- Ownership.
- Attachment state.
- Storage key.
- Visibility.
- Deletion eligibility.

Files are stored in object storage.

---

## 60. File Upload Rules

Validate:

- Purpose.
- MIME type.
- File signature where practical.
- File size.
- Image dimensions.
- Authenticated owner.
- Attachment compatibility.

Do not trust only the file extension.

---

## 61. File Lifecycle

Suggested states:

```text
pending
ready
attached
failed
deleted
```

Unattached files may be cleaned after a retention period.

---

## 62. Review Module

The review module owns:

- Review eligibility.
- One-review-per-booking rule.
- Rating.
- Comment.
- Moderation state.
- Business rating summaries.

Review creation requires completed booking ownership.

---

## 63. Reports Module

MVP reports:

- Daily booking totals.
- Completed services.
- Cancellation count.
- No-show count.
- Gross paid amount.
- Pending amount.
- Refund amount.
- Average wait time.
- Active queue count.

Reports do not mutate transactional state.

---

## 64. Audit Module

Audit records include:

- Actor user ID.
- Actor role.
- Business ID.
- Outlet ID.
- Action.
- Resource type.
- Resource ID.
- Previous-state summary.
- New-state summary.
- Reason.
- Request ID.
- Timestamp.

Audit logging is required for:

- Permission changes.
- Business verification.
- Manual cancellation.
- Queue reordering.
- Manual payment confirmation.
- Refunds.
- Administrative correction.

---

## 65. Outbox Module

Suggested fields:

```text
id
type
aggregate_type
aggregate_id
payload
status
attempt_count
next_attempt_at
claimed_at
processed_at
last_error
created_at
```

Suggested states:

```text
pending
processing
processed
failed
dead_letter
```

---

## 66. Worker

The worker processes:

- Outbox events.
- Push notifications.
- Payment expiration.
- Booking reminders.
- Refund reconciliation.
- Provider retries.
- Session cleanup.
- File cleanup.
- No-show evaluation.

The worker may run in the same process during early development and as a separate process in staging and production.

---

## 67. Job Claiming

Job claiming must prevent duplicate processing.

Recommended approach:

- Select due rows.
- Lock rows with `FOR UPDATE SKIP LOCKED`.
- Mark rows as claimed.
- Execute the job.
- Store result.
- Retry with backoff when allowed.

Jobs remain idempotent even after worker crashes.

---

## 68. Retry Policy

Retry only transient failures.

Transient examples:

- Provider timeout.
- Temporary connection failure.
- Rate limit.
- Provider 5xx response.

Final examples:

- Invalid signature.
- Invalid request.
- Resource not found.
- Permission denied.
- Invalid state transition.

Use bounded exponential backoff.

---

## 69. Health Checks

Endpoints:

```text
GET /health/live
GET /health/ready
```

Readiness checks:

- Database connectivity.
- Required migrations.
- Redis when mandatory.
- Critical configuration.
- Worker state when deployed together.

External payment and push outages should not automatically make read-only APIs unavailable.

---

## 70. Structured Logging

Required fields:

```text
timestamp
level
service
environment
requestId
traceId
userId
businessId
outletId
module
action
durationMs
result
errorCode
```

Never log:

- Passwords.
- Tokens.
- Provider secrets.
- Raw sensitive webhook data.
- Unredacted personal information.

---

## 71. Request ID

Request-ID behavior:

- Accept valid `X-Request-Id`.
- Generate when absent.
- Return in response.
- Include in logs.
- Propagate to provider calls when useful.
- Include in audit records.

WebSocket commands use their own request IDs.

---

## 72. Metrics

Recommended metrics:

```text
http_requests_total
http_request_duration_seconds
http_errors_total
booking_created_total
booking_conflicts_total
payment_webhooks_total
payment_webhook_failures_total
queue_commands_total
queue_conflicts_total
outbox_pending_total
outbox_failures_total
push_failures_total
websocket_connections
```

Avoid high-cardinality labels such as user IDs.

---

## 73. Error Tracking

Capture:

- Unexpected exceptions.
- Provider failures.
- Worker failures.
- Webhook failures.
- Migration failures.
- Repeated queue conflicts.

Attach safe context:

- Request ID.
- Environment.
- Release version.
- Module.
- Error code.
- Safe resource IDs.

---

## 74. Rate Limiting

Rate-limited areas:

- Login.
- Registration.
- Password reset.
- Payment refresh.
- File uploads.
- Search abuse.
- Device registration.
- Administrative endpoints.

Rate-limit keys may include:

- IP.
- User ID.
- Device ID.
- Endpoint.
- Business ID.

---

## 75. Input Validation

DTO validation handles:

- Required fields.
- Length.
- Format.
- Enum.
- Numeric range.
- Date format.
- Timezone.
- Money.
- Nested structure.

Application validation handles:

- Resource existence.
- Ownership.
- Business relationship.
- Current state.
- Business rules.

DTO validation is not business validation.

---

## 76. Output Serialization

Responses must:

- Exclude internal fields.
- Exclude secrets.
- Exclude database implementation details.
- Present dates consistently.
- Present money consistently.
- Filter private customer data.
- Use stable public enums.

Use response DTOs or presenters.

---

## 77. API Documentation

OpenAPI must document:

- Endpoints.
- Authentication.
- Request DTOs.
- Response DTOs.
- Error responses.
- Pagination.
- Idempotency headers.
- Example payloads.
- Enum values.

Generated contract artifact:

```text
packages/api-contracts/openapi/antrein-v1.json
```

---

## 78. OpenAPI Rules

- Controllers include response schemas.
- Shared response envelopes are reusable.
- Error examples use stable codes.
- Internal endpoints are excluded or protected.
- Webhooks document provider-specific behavior.
- OpenAPI generation runs in CI.

---

## 79. Testing Strategy

Required test levels:

- Unit tests.
- Repository integration tests.
- Transaction integration tests.
- Concurrency tests.
- End-to-end tests.
- Contract tests.
- Provider-adapter tests.
- Worker tests.

Critical correctness is not complete with unit tests alone.

---

## 80. Unit Tests

Targets:

- Status transitions.
- Deposit calculation.
- Cancellation eligibility.
- Refund calculation.
- Permission policy.
- Queue ordering.
- Event mapping.
- Value objects.
- Provider response mapping.

Unit tests should not require PostgreSQL.

---

## 81. Integration Tests

Use a real PostgreSQL instance.

Targets:

- Prisma repositories.
- Unique constraints.
- Foreign keys.
- Transactions.
- Rollback.
- Booking overlap.
- Queue counter.
- Idempotency.
- Webhook duplication.
- Outbox claiming.
- Authorization queries.

SQLite is not a substitute for PostgreSQL-specific behavior.

---

## 82. Concurrency Tests

Required scenarios:

1. Two users book the same staff slot.
2. Two check-in requests target the same booking.
3. Multiple queue numbers are generated simultaneously.
4. Duplicate webhook events arrive simultaneously.
5. Two staff members call the same queue entry.
6. Two refresh requests rotate the same refresh token.
7. Two refund requests target the same payment.
8. Two identical idempotency requests arrive together.

Tests must prove durable invariants.

---

## 83. End-to-End Tests

### Customer Flow

```text
Register
→ Login
→ Browse business
→ Get availability
→ Create booking
→ Complete sandbox payment
→ Check in
→ Observe queue state
→ Complete service
→ Submit review
```

### Business Flow

```text
Create business
→ Configure outlet
→ Create service
→ Invite staff
→ Configure schedule
→ Receive booking
→ Manage queue
→ Confirm payment
→ Complete service
→ Read report
```

---

## 84. Contract Tests

Verify:

- Response envelopes.
- Error codes.
- Required fields.
- Nullability.
- Date format.
- Money format.
- Pagination metadata.
- OpenAPI generation.
- Generated Dart-client compatibility.
- WebSocket event schema.

---

## 85. Test Data

Provide:

- Factories.
- Builders.
- Seed scenarios.
- Deterministic clock.
- Fake ID generator.
- Fake payment provider.
- Fake push provider.
- Test object storage.

Tests must not depend on real external providers.

---

## 86. Clock Abstraction

Time-sensitive modules should depend on:

```ts
interface ClockPort {
  now(): Date;
}
```

Use cases:

- Token expiration.
- Booking lead time.
- Payment expiration.
- Check-in window.
- No-show.
- Reminder scheduling.

---

## 87. ID Generation

Critical code may use:

```ts
interface IdGeneratorPort {
  next(prefix: string): string;
}
```

Tests should support deterministic IDs.

---

## 88. Local Development

Docker Compose should provide:

```text
postgres
redis
object-storage
optional mail catcher
```

Recommended commands:

```text
make bootstrap
make dev
make test
make test-integration
make migrate
make seed
```

---

## 89. Seed Data

Seed data should include:

- Demo customer.
- Demo owner.
- Demo staff.
- One active business.
- One outlet.
- Several services.
- Operating hours.
- Staff schedule.
- Optional bookings.
- Optional queue state.

Seed data must not run automatically in production.

---

## 90. Database Migrations

Rules:

- Prisma migrations are committed.
- Migration names are descriptive.
- Production migrations are controlled.
- Destructive changes use expand-and-contract.
- Seeds remain separate.
- Migration failure blocks release.
- Staging rehearses risky migrations.

---

## 91. Docker Image

Requirements:

- Multi-stage build.
- Production dependencies only.
- Non-root user.
- Health check.
- No embedded secrets.
- Deterministic build.
- Release metadata.

---

## 92. Deployment Units

Initial units:

```text
api
worker
```

Shared dependencies:

```text
PostgreSQL
Redis
Object storage
```

API and worker may use one image with different commands.

---

## 93. Environment Strategy

### Local

- Local Docker dependencies.
- Fake or sandbox providers.
- Verbose logs.
- Seed data.

### Development

- Shared dev API.
- Sandbox integrations.
- Test users.
- Debug observability.

### Staging

- Production-like configuration.
- Separate database.
- Migration rehearsal.
- E2E testing.
- Release candidate.

### Production

- Managed secrets.
- HTTPS and WSS.
- Backups.
- Monitoring.
- Restricted documentation.
- Controlled migrations.
- Production providers.

---

## 94. Production Security

Required:

- HTTPS.
- WSS.
- Strong secrets.
- Database least privilege.
- Network restrictions.
- Protected Swagger.
- Protected admin endpoints.
- Dependency scanning.
- Container scanning.
- Log redaction.
- Backup protection.
- Audit logs.
- Provider-secret rotation procedure.

---

## 95. Backup and Recovery

Requirements:

- Automated PostgreSQL backups.
- Restore tests.
- Point-in-time recovery when available.
- Durable object storage.
- Recovery runbook.
- Retention policy.
- Payment and audit history retention.
- No correctness dependency on Redis backups.

---

## 96. Performance Expectations

Initial goals:

- Typical reads remain responsive under normal mobile usage.
- Lists are paginated.
- Availability queries use proper indexes.
- Booking transactions remain short.
- Queue commands remain low latency.
- Webhook acknowledgement does not wait for notification delivery.
- Worker backlog is observable.
- Provider calls use explicit timeouts.

---

## 97. Query Performance

Requirements:

- Add indexes based on real filters and joins.
- Avoid N+1 queries.
- Avoid unnecessarily large relation graphs.
- Use projections.
- Use pagination.
- Inspect slow queries.
- Keep reporting queries away from mutation paths.

---

## 98. Caching

Cache only after measurement.

Potential candidates:

- Public business details.
- Service lists.
- Static configuration.

Do not cache as authoritative:

- Availability.
- Booking state.
- Payment state.
- Queue state.
- Permissions.

---

## 99. Security Review Checklist

Before release:

- Public routes are intentional.
- Authentication guard is global.
- Business ownership is checked.
- Outlet scope is checked.
- File ownership is checked.
- Payment-webhook signature is verified.
- Raw webhook body is handled safely.
- Idempotency is enforced.
- Rate limits exist.
- Secrets are not committed.
- Logs are redacted.
- Admin actions are audited.
- Production errors hide stack traces.

---

## 100. Module Completion Criteria

A backend module is complete when:

- Domain responsibility is clear.
- Public application interface exists.
- Controllers are thin.
- DTO validation exists.
- Authorization exists.
- Error codes are mapped.
- Database constraints exist.
- Transactions are defined.
- Unit tests pass.
- Integration tests pass.
- OpenAPI is updated.
- Audit and outbox behavior exist where required.
- Logs and metrics exist for critical paths.

---

## 101. Vertical Slice Delivery

Preferred sequence:

```text
API contract
→ Database migration
→ Domain rule
→ Repository
→ Use case
→ Controller
→ OpenAPI
→ Unit test
→ Integration test
→ Flutter integration
→ End-to-end test
```

Do not finish every backend module before integrating Flutter.

---

## 102. Backend Milestones

### B0 — Bootstrap

- NestJS project.
- TypeScript strict mode.
- Configuration validation.
- Logging.
- Global validation.
- Error filter.
- Response envelope.
- Request ID.
- Health endpoints.
- Docker Compose.

### B1 — Database Foundation

- Prisma.
- PostgreSQL.
- Migration workflow.
- Seed workflow.
- Transaction helper.
- Repository conventions.
- Test database.

### B2 — Authentication

- Registration.
- Login.
- Access token.
- Refresh token.
- Logout.
- Password reset.
- Global authentication guard.
- Session tests.

### B3 — Business Foundation

- Users.
- Businesses.
- Outlets.
- Memberships.
- Permissions.
- Business setup.
- Owner authorization.

### B4 — Catalog and Scheduling

- Services.
- Staff.
- Operating hours.
- Closed dates.
- Staff schedule.
- Availability query.

### B5 — Booking

- Booking creation.
- Booking snapshot.
- Conflict prevention.
- Booking history.
- Cancellation.
- Idempotency.

### B6 — Payment

- Provider port.
- Sandbox adapter.
- Payment creation.
- Webhook.
- Expiration.
- Pay-at-location.
- Refund.
- Reconciliation.

### B7 — Queue

- Check-in.
- Queue counter.
- Queue entry.
- Queue commands.
- Queue versioning.
- Walk-in.
- No-show.

### B8 — Real-Time and Notification

- WebSocket authentication.
- Subscriptions.
- Transactional outbox.
- Worker.
- Push provider.
- Notification history.
- Reconnect-safe events.

### B9 — Review and Reporting

- Reviews.
- Rating summary.
- Daily reports.
- Operational queries.

### B10 — Production Readiness

- Observability.
- Rate limiting.
- Security scanning.
- Backup strategy.
- CI/CD.
- Staging deployment.
- Load and concurrency testing.
- Runbooks.

---

## 103. CI Pipeline

```text
Install dependencies
→ Format check
→ Lint
→ Type check
→ Generate Prisma client
→ Validate schema
→ Start test dependencies
→ Unit tests
→ Integration tests
→ E2E tests
→ Generate OpenAPI
→ Validate contract
→ Build application
→ Build Docker image
→ Security scan
```

---

## 104. Pull Request Requirements

Every backend PR should include:

- Clear scope.
- Related document or issue.
- Migration when schema changes.
- API contract update when interfaces change.
- Tests.
- Error codes.
- Authorization review.
- Transaction review.
- Observability review.
- Rollout note for risky changes.

---

## 105. Coding Standards

- TypeScript strict mode.
- No untyped `any` without justification.
- Explicit return types for public functions.
- Avoid hidden side effects.
- Use descriptive domain names.
- Keep controllers thin.
- Keep transactions explicit.
- Keep provider-specific types inside adapters.
- Prefer composition over inheritance.
- Document non-obvious invariants.

---

## 106. Naming Conventions

Good examples:

```text
CreateBookingUseCase
BookingRepository
PaymentProviderPort
PrismaBookingRepository
BookingSlotUnavailableError
QueueEntryCalledEvent
```

Avoid vague names:

```text
Helper
Manager
Util
CommonService
ProcessData
HandleThing
```

---

## 107. DTO Rules

- Request DTOs validate transport input.
- Response DTOs define public shape.
- Application input types remain separate where useful.
- Prisma types do not leak.
- Provider types do not leak.
- Domain entities do not require transport decorators.

---

## 108. Repository Rules

Repositories should:

- Expose domain-relevant methods.
- Use projections.
- Accept transaction context where required.
- Avoid generic `findAll` abstractions.
- Map persistence records into domain or application models.
- Support dedicated read models where appropriate.

---

## 109. Read and Write Separation

Formal CQRS is not required.

Practical separation is encouraged:

- Commands change state.
- Queries return read models.
- Reports use optimized projections.
- Mutation repositories protect invariants.
- Presenters define public output.

---

## 110. Provider Failure Policy

### Payment Provider Unavailable

- Return a recoverable error.
- Keep local state consistent.
- Never claim payment success.
- Reconcile later when appropriate.

### Push Provider Unavailable

- Keep notification pending.
- Retry asynchronously.
- Do not fail booking or payment.

### Object Storage Unavailable

- Return upload failure.
- Do not attach invalid metadata.

### Redis Unavailable

- Preserve REST and durable state where deployment allows.
- Degrade real-time behavior safely.

---

## 111. Feature Flags

Server-side flags may control:

- Online payment.
- Deposits.
- Walk-ins.
- Queue reorder.
- QR check-in.
- Reviews.
- New queue algorithm.

The backend returns effective capabilities.

---

## 112. Administrative Functions

MVP admin functions may use protected endpoints or scripts.

Examples:

- Verify business.
- Suspend business.
- Suspend user.
- Inspect webhook failures.
- Retry outbox event.
- Reconcile payment.
- Correct invalid state with audit.

Administrative correction never bypasses audit requirements.

---

## 113. Operational Runbooks

Required before public production:

- Database restore.
- Payment-webhook failure.
- Outbox backlog.
- Push-provider outage.
- Redis outage.
- Failed migration.
- Secret rotation.
- Suspicious account activity.
- Duplicate provider events.
- Queue inconsistency.
- File-storage outage.

---

## 114. Open Backend Decisions

Resolve before dependent implementation:

- Final payment provider.
- Final push provider.
- Access-token lifetime.
- Refresh-token lifetime.
- Identifier format.
- Booking-overlap constraint strategy.
- Queue-counter implementation.
- Whether API and worker share one process in MVP.
- Whether Redis is mandatory in staging.
- File-size limits.
- Rate-limit values.
- Payment-expiration duration.
- Idempotency retention.
- Whether service completion requires full payment.
- Whether customer self-check-in is enabled.
- Whether business verification blocks discovery.
- Whether staff deactivation is allowed with future bookings.
- Whether generated OpenAPI artifacts are committed.

---

## 115. Backend Acceptance Criteria

The backend is ready for MVP when:

- Local setup is reproducible.
- Authentication is secure.
- Authorization protects every resource.
- Business setup works.
- Services and staff are manageable.
- Availability is calculated.
- Booking conflicts are prevented under concurrency.
- Payment sandbox works.
- Webhooks are verified and idempotent.
- Pay-at-location works.
- Refund flow works.
- Check-in is idempotent.
- Queue numbers remain unique under concurrency.
- Queue commands use version checks.
- WebSocket events are versioned.
- Notifications use an outbox and worker.
- Reviews require completed bookings.
- Daily reports are available.
- OpenAPI matches the API contract.
- CI passes.
- Logs, health checks, and metrics exist.
- Production-like Docker deployment works.

---

## 116. Final Backend Statement

The AntreIn backend is a NestJS modular monolith designed around correctness, explicit domain boundaries, and safe integration with Flutter and external providers.

Core request flow:

```text
Thin Controllers
→ Application Use Cases
→ Domain Rules
→ Prisma Repositories
→ PostgreSQL Durable State
```

Asynchronous delivery:

```text
Commit Business State
→ Write Outbox Event
→ Worker Processes Event
→ WebSocket and Push Delivery
```

Critical correctness:

```text
Server-Side Validation
+ Database Constraints
+ Transactions
+ Idempotency
+ Concurrency Tests
```

The backend must remain simple enough to finish while strict enough to prevent invalid booking, payment, and queue states.
