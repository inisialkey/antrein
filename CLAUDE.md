# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository State

Backend foundation (M1) is scaffolded and green: `apps/api` runs NestJS 11 with health endpoints, response/error envelopes, env validation, Prisma 7 + PostgreSQL, and migrations 001–003 (users, auth sessions, password reset tokens, devices, notification preferences). `apps/mobile` and `infrastructure/` are still empty. Next milestone: M2 authentication (`docs/backend/authentication.md`). CI workflows skip themselves until the relevant app manifest exists (`apps/mobile/pubspec.yaml` still pending).

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

From `apps/api` directly: `npm run test -- --testPathPattern id.spec` for a single test file, `npm run lint`, `npm run typecheck`, `npm run format:check`, `npm run build`, `npm run openapi:generate` (writes `packages/api-contracts/openapi/antrein-v1.json`).

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
- Queue command safety: architecture doc says `Idempotency-Key`; `realtime-queue.md` uses `expectedVersion` optimistic concurrency (keys only for check-in/recall) → `QUEUE_VERSION_CONFLICT` on stale version. Follow realtime-queue; decide per command.
- Session-state enums and provider-port method signatures differ slightly across docs — resolve in an ADR when implementing.

## Open Decisions

Most former open decisions are now ratified in `docs/adr/` (0009–0023): npm/Node 22, prefixed-ULID text IDs, token TTLs 15m/30d, shared multi-role account, self-serve auto-active businesses, check-in by customer AND staff, automatic booking confirmation, Midtrans sandbox, fixed-only deposits, default cancellation policy (360/120/50%/0%), demo scope (walk-ins + queue reorder in, any-available staff out), OneSignal, fees absorbed by business, public unauthenticated discovery, nested WS envelope. Product brief §34 carries the resolution index. ADRs 0001–0008 stay reserved for the architecture-doc decisions (arch §71).

Still open — decide (new ADR) when the depending milestone starts: booking-overlap strategy (exclusion constraint vs reservations table, M5), deposit-percentage rounding (only if percentage deposits return), queue command idempotency-vs-`expectedVersion` per command (M7), WS namespace layout (M7), payment refresh sync-vs-async (M6), whether the generated Dart client is committed, file-size/rate limits, one-user-multiple-businesses, data retention, demo hosting. Do not treat remaining example values as ratified.

## Implementation Order

Architecture doc §76: local infra → NestJS bootstrap → Prisma/PostgreSQL → API conventions + OpenAPI → auth → Flutter bootstrap/session → business/outlet/service/staff modules → scheduling → booking transaction → payment adapter + webhook → check-in/queue → WebSocket gateway → outbox + push → reviews/reports → deployment. After the foundation, work in vertical slices.
