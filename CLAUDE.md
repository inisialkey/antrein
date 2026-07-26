# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository State

M1–M8 plus the M9 realtime backbone (A+C) are implemented and green. `apps/api` runs NestJS 11 with health endpoints, envelopes, env validation, Prisma 7 + PostgreSQL (migrations 001–009), the full auth slice (Argon2id, HS256 access JWT + opaque rotating refresh per ADR 0024/0039, global `AuthGuard` + `@Public()`, in-memory rate limits, `EmailPort` → SMTP/Mailpit), M4 business modules (businesses/outlets/services/staff + memberships guard ladder, DB-backed idempotency, keyset pagination, audit log), M5 scheduling (outlet operating hours, closed dates, staff schedules + breaks, public availability §42 with pure slot engine in `src/modules/schedules/slots.ts`; staffId required per ADR 0019), M6 booking transaction slice (`src/modules/bookings/`: pay-at-location bookings end-to-end — create/list/get/cancel + business list/get/cancel §68.1 + PAL confirm §73 + payment reads; `booking_reservations` GiST exclusion per ADR 0027, per-business daily booking codes via `booking_code_counters` atomic upsert — `bookings_code_uq` is per `(business_id, booking_code)`, snapshots, status history, pure domain policies under `modules/bookings/domain/`), and M7 payments (`PaymentProviderPort` + deterministic `SandboxPaymentAdapter` in `src/infrastructure/payments/`, selected by `PAYMENT_PROVIDER` env, HMAC secret `PAYMENT_WEBHOOK_SECRET`; online `full_payment`/`deposit` bookings → `pending_payment` + checkout, provider-failure customer retry resumes the held slot per ADR 0040 via `transientErrorCodes` in `IdempotencyService`; `POST /webhooks/payments/{provider}` raw-body HMAC (`rawBody: true` in main.ts AND test apps) → `PaymentTransitionService`, the single idempotent path also used by `POST /payments/{id}/refresh` per ADR 0029; `payment_events` dedupe on `(provider, provider_event_id)`, amount/currency mismatch + late payment → `manual_review`, late success auto-refunds via `refunds.refundLatePayment`; `PaymentExpirationJob` 60s sweep per ADR 0033 (interval 0 in tests, drive `runOnce()`); refunds §74/§75 + cancellation refunds per ADR 0018/0040; deposit remainder settles via §73 PAL confirm, which creates the receipt row when no pending PAL payment exists), and M8 check-in + queue REST slice (`src/modules/bookings/queue/`: customer/staff check-in §64 → atomic `queue_counters` upsert + `queue_entries` waiting row, booking `confirmed→checked_in→waiting`; customer queue §81; staff outlet snapshot §82 carries per-entry `version`, operational names, no phone per ADR 0041; versioned commands call/recall/skip/return-to-waiting/start-service/complete/no-show §83–89 use `expectedVersion` → `QUEUE_VERSION_CONFLICT` via `versionedQueueUpdate`; `queue_entries_one_called_uq` + `queue_entries_one_in_service_per_staff_uq` partial unique indexes enforce ADR 0041, P2002 translated to `QUEUE_HAS_CALLED_ENTRY`/`STAFF_NOT_AVAILABLE`; walk-in §67 creates booking+snapshot+pending-PAL payment+entry in one tx with NO reservation; reorder §90 audited via `queue_reorders` + `audit.record`, needs `queue.reorder`, aggregate version guarded in `queue_counters.version`; booking-level no-show §68 for confirmed-never-checked-in; skip-return goes to end of queue, `sort_order integer` per ADR 0038; pure domain in `queue/domain/` — `queue-status.policy` (transitions + `bookingStatusForQueue` §9 mapping), `queue-math` (display-number/people-ahead/wait-estimate/check-in-window); `walk_in_customer_name`/`walk_in_phone_number` columns added to bookings; booking policy gained `waiting→no_show` for skipped-entry no-show). Queue lives INSIDE `modules/bookings` for the same atomicity reason as payments: check-in/commands mutate bookings+queue+reservation in one transaction and walk-in creates a booking, so a separate module would need bookings↔queue forwardRef cycles — `realtime-queue §72 modules/queues` is the target when WebSocket/outbox extraction justifies it. M9 realtime backbone (A+C) is implemented: `outbox_events` (migration 009) + a thin outbox marker `enqueueQueueEvent` written INSIDE every queue mutation tx (`queue-support.ts`, at the `command()` choke point + check-in/walk-in/reorder), drained by an in-process `OutboxDispatcherJob` (`modules/bookings/outbox-dispatcher.job.ts`, mirrors `PaymentExpirationJob` — interval poll, `runOnce()` in tests, and `NODE_ENV=test` skips auto-poll so specs pump it by hand to avoid pool-starvation flakiness) that claims via `FOR UPDATE SKIP LOCKED` (`infrastructure/outbox/outbox.ts`) and re-reads live state to publish `queue.entry.updated.v1` to the customer `user:{id}` room (§107) + `queue.snapshot.updated.v1` to the outlet room (§108) through a `RealtimePublisherPort`; the `/realtime` Socket.IO gateway (`infrastructure/realtime/`) does handshake-token auth (`connection.ready.v1` / disconnect), auto-joins `user:{id}`, and authorizes `subscription.join.v1` (booking-owner or outlet-member with `queue.read`, else `FORBIDDEN_QUEUE_RESOURCE`). In-memory adapter, NO Redis fan-out (ADR 0030/0035); a publish failure backs the row off (dead-letter after N) and never rolls back committed business state. Push (M9 B: `notifications`/`notification_deliveries`, `PushNotificationPort`) stays deferred. Payments/refunds stay INSIDE `modules/bookings` deliberately: webhook/cancel/expiration mutate bookings+payments in one transaction and cross-module table writes are forbidden — extraction deferred until a real consumer needs it. `apps/mobile` has the M3 Flutter bootstrap (auth/session skeleton) + M7 discovery/booking screens + M8 customer check-in/live queue (`features/customer_queue`) and the staff queue board (`features/business_queue`: outlet snapshot §82 + versioned call/recall/skip/return/start/complete/no-show §83–89 gated on `queue.manage`, live-refreshed over the `/realtime` WebSocket via a shared `RealtimeClient` (`core/realtime/`, `socket_io_client`): `business_queue` subscribes to the outlet room and refetches on `queue.snapshot.updated.v1`, `customer_queue` refetches on its own `queue.entry.updated.v1` (auto user room, no explicit subscribe), both with a slow safety poll behind the WS feed + reconnect→REST resync, `QUEUE_VERSION_CONFLICT` → resync; the business shell `business_home_page` resolves the member's business + primary outlet from the login `businessMemberships` — staff use assigned `outletIds`, owners fall back to the public business-detail primary outlet since no owner outlets-list endpoint exists; walk-in §67 + drag-reorder §90 deferred). Branching is gitflow: `main` (releases) ← `develop` ← `feature/*`. Next milestone: M9 push (B — `notifications`/`notification_deliveries` + `PushNotificationPort` + device registration + called/check-in mapping) and hardening (Redis multi-instance adapter, metrics, consistency jobs); the deferred `business_queue` walk-in §67 + drag-reorder §90 remain open too. CI runs api-ci and mobile-ci; mobile-ci also triggers on `packages/api-contracts/**`.

## What This Is

AntreIn — a mobile-first booking, payment, check-in, and real-time queue platform for barbershops in Indonesia (MVP vertical). Solo portfolio project: one Flutter app (customer + business roles) and one NestJS modular-monolith backend in a single monorepo.

## Documentation Map and Precedence

Conflict resolution order (higher wins for "what", lower docs win for implementation detail):

1. `docs/00-product-brief.md` — roles, journeys, business rules, booking/payment/queue status lifecycles and allowed transitions, MVP scope
2. `docs/01-system-architecture.md` — system structure, module boundaries, monorepo layout, deployment
3. `docs/02-api-contract.md` — every REST endpoint, WebSocket event, stable error code, response envelope, authorization matrix. Human-readable contract; the backend-generated OpenAPI (`packages/api-contracts/openapi/antrein-v1.json`) is the machine contract, and any mismatch between them is a defect
4. `docs/backend/` — backend-brief, database-design, authentication, booking-payment, realtime-queue
5. `docs/frontend/` — flutter-brief, app-architecture, navigation-flow, state-management, ui-feature-spec

The detail docs (4–5) are newer than the architecture doc in places — see Known Doc Conflicts below. Business-rule changes must update the relevant doc before code changes.

## Commands

Node 22 (`.nvmrc` — run `nvm use` first; Prisma 7 requires ≥22.12) and npm (ADR 0009). From repo root:

- `make bootstrap` — npm install, copy `.env.example` → `apps/api/.env`, start postgres/redis/minio via Docker Compose, migrate, generate Prisma client
- `make dev` — infra + API watch mode on :3000 (`/api/v1` prefix; Swagger UI at `/docs` outside production; Android emulator uses `http://10.0.2.2:3000/api/v1`)
- `make test` / `make test-integration` — unit tests / integration tests (creates + migrates `antrein_test` DB, needs Docker up)
- `make migrate` / `make seed` — `prisma migrate deploy` / seed script

From `apps/api` directly: `npm run test -- id.spec` for a single test file (Jest 30 — positional pattern, `--testPathPattern` was removed), `npm run lint`, `npm run typecheck`, `npm run format:check`, `npm run build`, `npm run openapi:generate` (writes `packages/api-contracts/openapi/antrein-v1.json`).

Prisma 7 specifics: no `url` in `schema.prisma` — the connection comes from `prisma.config.ts` (loads dotenv) for CLI and from `@prisma/adapter-pg` in `PrismaService` at runtime. Generated client lives at `src/generated/prisma/` (gitignored) — run `npx prisma generate` after schema changes and before typecheck. Migrations are hand-written SQL under `prisma/migrations/` following the numbered sequence in `database-design.md` §82.

Mobile (once scaffolded) CI order: `flutter pub get` → codegen (build_runner, gen-l10n) → format → analyze → unit → widget → contract compile check. Flutter version still unpinned — record in an ADR when scaffolding.

## Architecture

### Contract flow (the monorepo's spine)

NestJS DTOs/decorators → generated OpenAPI JSON → generated Dart client at `apps/mobile/lib/core/network/generated/`. Generated code is never hand-edited and generated DTOs never reach UI — always map to domain entities. Flutter never imports backend TypeScript; the backend never imports Dart.

### Backend (`apps/api`) — NestJS modular monolith

- Modules by capability under `src/modules/`: auth, users, businesses, outlets, memberships, services, staff, schedules, bookings, payments, queues, notifications, reviews, reports, files, audit, admin. Shared `src/common/` (guards, filters, pagination, validation) and `src/infrastructure/` (database, cache, storage, payments, notifications, realtime).
- Complex modules layer domain/application/infrastructure/presentation; controllers hold no business rules; Prisma records are never returned as public API models; cross-module calls go through public application services, never another module's tables.
- External providers sit behind ports (`PaymentProviderPort`, `PushNotificationPort`, `ObjectStoragePort`, `ClockPort`…). Payment candidates: Midtrans/Xendit sandbox. Push: OneSignal initially.
- PostgreSQL owns ALL durable state. Redis is ephemeral only (Socket.IO fan-out, rate limits, cache) — never bookings/payments/queues. Two deployment units, `api` and `worker` (one image, different commands); worker may run in-process early but stays logically separable.
- Transactional outbox: business state + `outbox_events` row commit in one transaction; worker claims with `FOR UPDATE SKIP LOCKED` and delivers push/realtime. Delivery failure never rolls back business state.
- REST for authoritative state, WebSocket (Socket.IO-compatible, `/realtime` namespace) for events. Events are versioned (`queue.entry.updated.v1`); clients compare versions and refetch REST on gaps. WS informs; REST recovers.

### Mobile (`apps/mobile`) — Flutter

- Feature-first: each feature has `data/{datasources,models,mappers,repositories}`, `domain/{entities,repositories,usecases}`, `presentation/{cubit,pages,widgets}`. Canonical folder/feature list is `docs/frontend/app-architecture.md` §3 (17 features, split `customer_queue`/`business_queue`), not the coarser list in the architecture doc.
- Stack: `flutter_bloc` (Cubit-first), `freezed` + `json_serializable`, `go_router` (named routes only), GetIt with manual registration (Cubits are factories, constructor-injected, never call GetIt internally), Dio, `flutter_secure_storage` for tokens, `intl` + ARB/gen-l10n.
- Two navigation shells — customer and business. The three product roles (customer, business_owner, staff) collapse into these two; owner vs staff differ only by permissions. Do not build a third shell.
- Dio refresh coordination: first 401 triggers refresh, other requests wait, then replay once. Mutations are not auto-retried unless idempotent.
- State conventions: shared `LoadStatus {initial, loading, success, empty, failure}` plus separate action booleans (`isRefreshing`, `isCancelling`) so refresh never blanks a screen. Errors map to a sealed `AppFailure` hierarchy that preserves the backend `error.code`. Realtime events route RealtimeClient → RealtimeEventRouter → feature Cubit; transport never touches UI state directly.
- Cross-feature imports only via the feature's public barrel (`features/booking/booking.dart`).
- Product copy is Bahasa Indonesia (localization keys are English camelCase); docs and code are English. Currency IDR, locale `id-ID`.

## Core Invariants (every change must respect these)

- **Backend is the source of truth** for prices, deposits, slots, eligibility, booking/payment status, queue numbers and order. Flutter submits choices, never authoritative outcomes; a client callback is never proof of payment.
- **Correctness lives in DB constraints, not read-then-write checks.** Booking overlap: exclusion constraint (`btree_gist` on a generated `tstzrange`) or a `booking_reservations` table — ADR decision. Queue numbers: atomic upsert on `queue_counters` (PK `(outlet_id, business_date)`) + `UNIQUE(outlet_id, business_date, queue_number)` + `UNIQUE(booking_id)`.
- **Idempotency is database-backed.** Critical mutations require `Idempotency-Key`; `idempotency_keys` is unique on `(scope_type, scope_id, action, key)`; same key + different payload → 409 `IDEMPOTENCY_KEY_REUSED`. Flutter creates the key when a logical submission begins and keeps it across retries.
- **Webhooks**: `POST /webhooks/payments/{provider}` with raw body preserved for signature verification; dedupe via `UNIQUE(provider, provider_event_id)` on `payment_events`; amount/currency/reference mismatch → store event for manual review, never mutate the payment.
- **Status transitions** only per product brief §16 (booking) and §16.2 (payment). Terminal states (`completed`, `cancelled`, `expired`, `no_show`) require an audited admin action to correct.
- **Authorization** = authentication + membership + permission + outlet scope + ownership. Global auth guard with `@Public()` opt-out. Knowing a resource ID is never permission. No RLS in MVP — app-layer checks.
- **Money is integer IDR** (`amount` + `currency`), never floats. Timestamps are `timestamptz`; outlet timezone `Asia/Jakarta`; queue rows carry a separate `business_date`.
- **Bookings snapshot** service name/duration/price/deposit at creation; history survives catalog changes (deactivate, don't delete, used services).
- Manual queue reordering, payment confirmation, refunds, permission changes → audit log. Customer-facing queue views never expose other customers' names/contacts.

## Backend Conventions

- Response envelope: `{success, data, meta{requestId, timestamp}}`; errors `{success: false, error{code, message, details}}` with stable `UPPER_SNAKE` codes grouped by domain (`BOOKING_*`, `PAYMENT_*`, `QUEUE_*`…) — full catalog in api-contract Part XVIII. Cursor pagination (opaque cursor, default limit 20, max 100).
- Public IDs are opaque and prefixed: `usr_`, `biz_`, `out_`, `svc_`, `stf_`, `bkg_`, `pay_`, `que_`… Bookings also get a human code `ANT-YYYYMMDD-NNNN` (display only, never authorization). Exact ID column type (text/uuid/ULID) is an open decision.
- Prisma: PascalCase models with `@@map`/`@map` to snake_case; `@db.Timestamptz(6)`; status columns are `text` + CHECK constraints (not Postgres enums), mirrored as TS enums kept in sync by migration tests. Repositories accept an optional `db: PrismaClient | Prisma.TransactionClient` so use cases control transactions.
- Raw-SQL migrations are expected for what Prisma DSL can't express: exclusion constraints, partial indexes, `btree_gist`, `pg_trgm`, generated columns. Seeds live in `apps/api/prisma/seed/`, separate from migrations, never auto-run in production.
- Cross-business integrity is not FK-enforced: child tables duplicate `business_id` and same-business validation happens inside app transactions. Lock ordering to avoid deadlocks: Booking → Payment → Refund → Reservation.
- Auth: Argon2id password hashing; JWT access token (~15 min default TTL); opaque rotating refresh token (~30 days) stored only as a hash, with `token_family_id` reuse-detection that revokes the whole family. TTL values are defaults, not ratified.
- Tests: Jest + Supertest; integration tests run against real PostgreSQL (Testcontainers/Docker) — SQLite is explicitly forbidden as a substitute. Required concurrency tests: duplicate bookings, duplicate queue numbers, webhook idempotency. Flutter uses `bloc_test`.

## Known Doc Conflicts

When these bite, trust the detail doc and record the resolution:

- Schedule table names: `database-design.md` (`outlet_operating_hours`, `staff_schedules`, `staff_schedule_breaks`) supersedes the architecture doc's `operating_hours`/`schedule_breaks`.
- Flutter folder/feature layout: `frontend/app-architecture.md` §3 supersedes architecture doc §12.
- WS event envelope: RESOLVED (ADR 0023) — nested `resource: {type, id}` + `eventId` per `realtime-queue.md`; architecture doc §30's flat `resourceId` is stale.
- Queue command safety: RESOLVED (ADR 0028) — staff commands use `expectedVersion` → `QUEUE_VERSION_CONFLICT`; check-in keeps `Idempotency-Key`; recall naturally idempotent. Architecture §3.7/§24 idempotency entries for queue commands are stale.
- Session-state enums and provider-port method signatures differ slightly across docs — resolve in an ADR when implementing.

## Open Decisions

Most former open decisions are now ratified in `docs/adr/` (0009–0023): npm/Node 22, prefixed-ULID text IDs, token TTLs 15m/30d, shared multi-role account, self-serve auto-active businesses, check-in by customer AND staff, automatic booking confirmation, Midtrans sandbox, fixed-only deposits, default cancellation policy (360/120/50%/0%), demo scope (walk-ins + queue reorder in, any-available staff out), OneSignal, fees absorbed by business, public unauthenticated discovery, nested WS envelope. Product brief §34 carries the resolution index. ADRs 0001–0008 stay reserved for the architecture-doc decisions (arch §71).

Architecture grilling (ADRs 0024–0033) added: new-row session rotation with family revocation, HS256 symmetric JWT, one owned business per user (`BUSINESS_LIMIT_REACHED`), booking overlap via `booking_reservations` exclusion-constraint table, queue `expectedVersion` model, synchronous payment refresh through the webhook transition path, single `/realtime` namespace with Redis adapter deferred, committed Dart client, service completion independent of balance, 30-minute payment expiration.

Contract defaults ratified in ADR 0034 (values normative in `docs/02-api-contract.md`): password 8–128 length-only, auth rate limits, geo discovery params reserved/ignored in v1, file limits 5 MB + 10 gallery, booking policy 60 min/30 d/3 active, check-in window −30/+15 min, idempotency retention 24 h/7 d.

Backend-brief grilling (ADRs 0035–0037): worker inline locally (`WORKER_MODE=inline`) / separate container staging+prod; Redis optional in all MVP environments (in-memory rate limits, mandatory only at >1 instance); staff deactivation blocked by future active bookings (`STAFF_HAS_ACTIVE_BOOKINGS` + ids in details); password-reset email via `EmailPort` → Mailpit locally (compose service, UI :8025), real ESP deferred with demo hosting.

Database grilling (ADR 0038): queue ordering `sort_order integer`; booking codes per-business daily sequence (`booking_code_counters` atomic upsert); one-active-outlet partial unique applied; rating aggregates stored + updated in review transaction; webhook payloads redacted-at-write (no encryption); outbox `processed` deleted after 30 d; permissions jsonb; RLS formally rejected.

Auth grilling (ADR 0039): Argon2id 64 MiB/t=3/p=4 pinned + rehash-on-login; refresh token = `sessionId.randomSecret`; strict reuse detection (family → compromised); email verification OUT of MVP; suspension accepts ≤15-min residual JWT window; logout deactivates device push; reset tokens 30 min single-use, completion revokes all sessions. Auth doc §9.1 composition rules corrected to length-only per ADR 0034.

Booking/payment grilling (ADR 0040): one pending online payment per booking (partial unique index); provider-creation failure → customer-driven idempotent retry, no worker retry, reservation held to 30-min expiry; late payment confirms only if reservation row still exists, else manual_review + refund; business cancellation = full refund + reason + audit (`booking.manage`); all five pay-at-location method labels; job cadence 60 s expiration / 5 min reconciliation / daily consistency.

Queue grilling (ADR 0041): one called entry per outlet+date and one in-service per staff (both partial unique indexes); skipped entries return to END of queue; pure check-in order (audited reorder only override); wait estimate = peopleAhead × outlet average; near-turn push deferred; no phone numbers in staff queue snapshot; display `A012` (prefix + 3-digit pad); gaps acceptable; aggregate version in `queue_counters.version`.

**All eight docs' open-decision lists are fully resolved (ADRs 0009–0041). No decision blocks any milestone.**

Still open — decide (new ADR) when relevant: deposit-percentage rounding (only if percentage deposits return), data retention, demo hosting, product name. Do not treat remaining example values as ratified.

## Implementation Order

Architecture doc §76: local infra → NestJS bootstrap → Prisma/PostgreSQL → API conventions + OpenAPI → auth → Flutter bootstrap/session → business/outlet/service/staff modules → scheduling → booking transaction → payment adapter + webhook → check-in/queue → WebSocket gateway → outbox + push → reviews/reports → deployment. After the foundation, work in vertical slices.
