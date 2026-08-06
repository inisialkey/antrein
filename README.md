# AntreIn

Mobile-first booking, payment, check-in, and real-time queue platform for barbershops in Indonesia. Monorepo: NestJS API (`apps/api`) + Flutter app (`apps/mobile`).

- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
- [Local services](#local-services)
- [Commands](#commands)
- [Demo data](#demo-data)
- [Mobile app](#mobile-app)
- [Features](#features)
- [API surface](#api-surface)
- [Realtime events](#realtime-events)
- [Background jobs](#background-jobs)
- [Configuration](#configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Deployment](#deployment)
- [Documentation map](#documentation-map)

## Prerequisites

- **Node 22.12+** (`.nvmrc` pins major 22) — not optional, see below
- Docker + Docker Compose
- Flutter (mobile only; version unpinned)

Node 22 is a hard requirement in both directions: Prisma 7 needs ≥ 22.12, and the
`argon2` native addon is compiled for the Node 22 ABI. Under Node 18 the API
**segfaults on boot with no log output at all** while `nest start --watch` stays
alive — it looks like the server is running when nothing is listening. See
[Troubleshooting](#troubleshooting).

```bash
node -v          # must print v22.12 or newer
nvm alias default 22   # make it the default for new shells
```

## Quickstart

```bash
nvm use            # reads .nvmrc → Node 22
make bootstrap     # install deps, start postgres/redis/minio/mailpit, migrate, generate Prisma client
make dev           # infra + API in watch mode on :3000
```

Verify:

```bash
curl localhost:3000/health/live    # {"status":"ok",...}
curl localhost:3000/health/ready   # {"status":"ready","checks":{"database":"up","migrations":"up"}}
open  http://localhost:3000/docs   # Swagger UI (disabled in production)
```

Health endpoints are **excluded from the global prefix** (`main.ts` →
`setGlobalPrefix('api/v1', { exclude: [...] })`), so they live at `/health/live`
and `/health/ready` — *not* under `/api/v1`. Everything else is `/api/v1/*`.

## Local services

`docker-compose.yml` brings up:

| Service | Port | Notes |
|---|---|---|
| API | 3000 | `http://localhost:3000/api/v1` · Swagger `/docs` |
| PostgreSQL | 5432 | `postgresql://postgres:postgres@localhost:5432/antrein` — owns all durable state |
| Redis | 6379 | Ephemeral only: Socket.IO fan-out, rate limits, cache. Optional — the API degrades to in-memory |
| MinIO | 9000 / 9001 | Object storage + console (`minioadmin`/`minioadmin`) |
| Mailpit | 1025 / 8025 | SMTP sink + web UI — password-reset emails land here |

## Commands

From the repo root:

| Command | What |
|---|---|
| `make bootstrap` | Install, start infra, migrate, generate Prisma client |
| `make dev` | Infra + API watch mode |
| `make test` | Backend unit tests |
| `make test-integration` | Integration tests against real PostgreSQL (`antrein_test`) |
| `make migrate` | Apply migrations (`prisma migrate deploy`) |
| `make seed` | Seed development data |
| `make seed-demo` | Seed the demo business, catalog, staff and logins |
| `make docker-build` | Build the production image locally (same build CI and the VPS run) |
| `make mobile-dev` / `mobile-staging` / `mobile-production` | Run the Flutter app on a flavor |

From `apps/api`:

| Command | What |
|---|---|
| `npm run test -- id.spec` | One test file (Jest 30 — positional pattern; `--testPathPattern` was removed) |
| `npm run lint` / `format:check` / `typecheck` | ESLint / Prettier / `tsc --noEmit` |
| `npm run build` / `start` | `nest build` / run `dist/main.js` |
| `npm run openapi:generate` | Regenerate `packages/api-contracts/openapi/antrein-v1.json` |
| `npx prisma generate` | Regenerate the client into `src/generated/prisma/` (gitignored) — run after schema changes, before typecheck |

Prisma 7 has no `url` in `schema.prisma`: the CLI reads `prisma.config.ts` (which
loads dotenv) and the runtime uses `@prisma/adapter-pg` in `PrismaService`.
Migrations are hand-written SQL under `apps/api/prisma/migrations/` (11 so far,
`001_extensions` → `011_reviews`).

## Demo data

`make seed-demo` is idempotent — one barbershop, one outlet, 4 services, 2 barbers
with schedules, plus logins. Every account shares the password `DemoAntre123`:

| Account | Role |
|---|---|
| `owner@demo.antrein.id` | Business owner |
| `andi@demo.antrein.id`, `sinta@demo.antrein.id` | Barbers (staff) |
| `dewi@demo.antrein.id`, `rizky@demo.antrein.id` | Customers |

## Mobile app

Flutter, feature-first, `flutter_bloc` (Cubit) + `go_router` + GetIt + Dio. Two
navigation shells only — customer and business; owner vs staff differ by
permission, not by shell.

```bash
make mobile-dev    # flutter run -t lib/main_dev.dart --dart-define-from-file=config/flavors/dev.json
```

Flavors carry dart-defines only (no native productFlavors, so **no `--flavor`
flag**). `config/flavors/dev.json` points at `http://localhost:3000/api/v1`, and
`make mobile-dev` runs `adb reverse tcp:3000 tcp:3000` first so both an emulator
and a USB device reach the host API. Launching from VS Code instead? Run that
`adb reverse` once per device connection. A LAN IP works too but breaks whenever
DHCP moves it, a VPN is on, or the router isolates Wi-Fi clients — all of which
show up as `type=connectionError` in the Dio log. Push is off unless
`ONESIGNAL_APP_ID` is built in via `--dart-define`, so dev/CI/test carry no push
runtime.

Implemented features (`apps/mobile/lib/features/`):

| Feature | What |
|---|---|
| `auth` | Register, login, session/token refresh, device registration |
| `discovery` | Business list/detail, service catalog, availability slots |
| `booking` | Create/list/detail/cancel, payment checkout, review entry point |
| `customer_queue` | Check-in, live queue position over WebSocket |
| `business_queue` | Staff queue board, versioned commands, walk-ins, drag-reorder |
| `business_dashboard` | Business shell — resolves business + primary outlet from memberships |
| `reports` | Daily summary — day switcher + stat cards |
| `reviews` | Inline 1–5 star review form on a completed booking |
| `profile` | Account profile |

## Features

Backend is the source of truth for prices, deposits, slots, eligibility, statuses,
queue numbers and order. The client submits choices, never authoritative outcomes.

| Domain | What works |
|---|---|
| **Auth** | Argon2id hashing (64 MiB/t=3/p=4, rehash-on-login), HS256 access JWT (~15 min), opaque rotating refresh token (~30 d) with `token_family_id` reuse detection, password reset over SMTP, global `AuthGuard` + `@Public()`, in-memory rate limits |
| **Business** | Business + primary outlet creation (one owned business per user), outlets, service catalog, staff + email invitations, membership permission ladder, DB-backed idempotency, keyset pagination, audit log |
| **Scheduling** | Outlet operating hours, closed dates, staff weekly schedules + breaks, public availability with a pure slot engine (`modules/schedules/slots.ts`); `staffId` required |
| **Booking** | Create/list/get/cancel for customers and business, overlap prevented by a `booking_reservations` GiST exclusion constraint, per-business daily booking codes (`ANT-YYYYMMDD-NNNN`, display only), service snapshots, status history, pure domain policies |
| **Payments** | `PaymentProviderPort` + deterministic sandbox adapter, online `full_payment`/`deposit` → `pending_payment` + checkout, raw-body HMAC webhook, `payment_events` dedupe on `(provider, provider_event_id)`, amount/currency mismatch → `manual_review`, synchronous refresh through the same idempotent path, pay-at-location confirm, refunds + cancellation refunds, 30-minute expiration sweep |
| **Queue** | Check-in by customer or staff (−30/+15 min window), atomic `queue_counters` upsert, versioned staff commands (call/recall/skip/return/start/complete/no-show) guarded by `expectedVersion` → `QUEUE_VERSION_CONFLICT`, one called entry per outlet+date and one in-service per staff (partial unique indexes), walk-ins, audited manual reorder, display numbers `A012` |
| **Realtime** | Socket.IO `/realtime` namespace with handshake-token auth, transactional outbox (`outbox_events`) drained by an in-process dispatcher claiming rows `FOR UPDATE SKIP LOCKED`, optional Redis adapter for multi-instance fan-out |
| **Notifications** | In-app notification list with keyset cursor + read/read-all, device register/remove, `PushNotificationPort` with `log` / `none` / `onesignal` adapters, per-user `queue_updates` preference, Bahasa copy |
| **Reviews** | One review per completed booking, live summary (average/count/distribution), rating aggregates recomputed inside the review transaction under a row lock |
| **Reports** | Daily operational summary per outlet — booking status counts, active queue, average wait, payment gross/pending/refunded. Read-only |
| **Ops** | Prometheus `/metrics` (gated), payment reconciliation and consistency-check jobs, Docker image, VPS Compose stack, CI/CD |

Payments, refunds and queue deliberately live **inside** `modules/bookings`:
webhook/cancel/expiration/check-in mutate bookings + payments + queue + reservation
in one transaction, and cross-module table writes are forbidden.

## API surface

63 documented endpoints. Swagger UI at `/docs` and
`packages/api-contracts/openapi/antrein-v1.json` are authoritative — the table
below is a map, not a contract. `docs/02-api-contract.md` is the human-readable
version; any mismatch between the two is a defect.

All paths are prefixed `/api/v1`.

| Domain | Endpoints |
|---|---|
| **auth** | `POST /auth/register` · `/auth/login` · `/auth/refresh` · `/auth/logout` · `/auth/password/forgot` · `/auth/password/reset` |
| **users** | `GET /me` · `PUT /me/devices/{deviceId}` · `DELETE /me/devices/{deviceId}` |
| **businesses** | `GET /businesses` · `POST /businesses` · `GET|PATCH /businesses/{id}` · `GET /businesses/{id}/management` |
| **outlets** | `PATCH /businesses/{id}/outlets/{outletId}` |
| **services** | `GET|POST /businesses/{id}/services` · `PATCH /businesses/{id}/services/{serviceId}` · `POST .../deactivate` |
| **staff** | `GET /businesses/{id}/staff` · `PATCH|POST .../staff/{staffId}[/deactivate]` · `POST .../staff/invitations` · `POST /staff/invitations/{id}/accept` |
| **schedules** | `GET|PUT .../outlets/{outletId}/operating-hours` · `GET|POST .../closed-dates` · `PUT .../staff/{staffId}/schedule` · `GET /businesses/{id}/availability` |
| **bookings** | `POST|GET /bookings` · `GET /bookings/{id}` · `POST /bookings/{id}/cancel` · `GET /bookings/{id}/payments` |
| **business-bookings** | `GET .../bookings[/{id}]` · `POST .../bookings/{id}/cancel` · `POST .../payments/pay-at-location/confirm` · `POST .../payments/{paymentId}/refunds` |
| **payments** | `GET /payments/{id}` · `POST /payments/{id}/refresh` · `GET /refunds/{id}` |
| **queue** (customer) | `POST /bookings/{id}/check-in` · `GET /bookings/{id}/queue` |
| **business-queue** | `GET .../outlets/{outletId}/queue` · `POST .../queue/{entryId}/{call\|recall\|skip\|return-to-waiting\|start-service\|complete\|no-show}` · `POST .../queue/reorder` · `POST .../walk-ins` · `POST .../bookings/{id}/no-show` |
| **notifications** | `GET /notifications[/{id}]` · `POST /notifications/{id}/read` · `POST /notifications/read-all` |
| **reviews** | `POST /bookings/{id}/review` · `GET /businesses/{id}/reviews` |
| **reports** | `GET /businesses/{id}/reports/daily-summary` |

Not in OpenAPI (deliberately excluded):

| Endpoint | Notes |
|---|---|
| `GET /health/live`, `GET /health/ready` | Outside the `/api/v1` prefix. `ready` checks database + migrations |
| `POST /api/v1/webhooks/payments/{provider}` | Raw-body HMAC signature required — returns 401 without it. Note this **is** under the prefix |
| `GET /api/v1/metrics` | Prometheus text. 404 unless `METRICS_ENABLED=true`; 404-hides on a wrong `METRICS_TOKEN` |

Conventions: envelope `{success, data, meta{requestId, timestamp}}`, errors
`{success: false, error{code, message, details}}` with stable `UPPER_SNAKE` codes.
Opaque prefixed IDs (`usr_`, `biz_`, `bkg_`, `pay_`, `que_`…). Cursor pagination,
default limit 20, max 100. Money is integer IDR. Critical mutations require an
`Idempotency-Key`.

## Realtime events

Socket.IO namespace `/realtime`. The Socket.IO HTTP path stays the default
`/socket.io/` — `/realtime` is a **namespace**, negotiated inside the protocol,
not a URL path. Auth is a handshake token.

| Event | Direction | Notes |
|---|---|---|
| `connection.ready.v1` | server → client | Emitted after handshake auth; the socket auto-joins `user:{id}` |
| `subscription.join.v1` | client → server | Join an outlet room — booking-owner or outlet member with `queue.read`, else `FORBIDDEN_QUEUE_RESOURCE` |
| `subscription.joined.v1` | server → client | Join acknowledged |
| `queue.entry.updated.v1` | server → client | To the customer's `user:{id}` room |
| `queue.snapshot.updated.v1` | server → client | To the outlet room |

WebSocket informs, REST recovers: events are versioned, clients compare versions
and refetch REST on gaps. A publish failure backs the outbox row off and never
rolls back committed business state.

## Background jobs

In-process (`WORKER_MODE=inline`; ADR 0045 keeps the worker inline in production
too). All skip auto-polling under `NODE_ENV=test` and expose `runOnce()` so specs
drive them by hand.

| Job | Cadence | What |
|---|---|---|
| `OutboxDispatcherJob` | poll | Claims `outbox_events` `FOR UPDATE SKIP LOCKED`, publishes WS events, then fires push |
| `PaymentExpirationJob` | 60 s | Expires unpaid online payments past the 30-minute window |
| `PaymentReconciliationJob` | 5 min | Re-queries the provider for stale pending payments and re-settles stuck refunds |
| `ConsistencyCheckJob` | daily | **Detector only** — never auto-repairs. Counts orphan/missing reservations, queue↔booking mismatches, stale refunds, outbox backlog |

## Configuration

`.env.example` → `apps/api/.env` (done by `make bootstrap`). Notable keys:

| Key | Default | Notes |
|---|---|---|
| `PORT`, `API_PREFIX` | `3000`, `/api/v1` | |
| `DATABASE_URL` | local postgres | Owns all durable state |
| `REDIS_URL` | local redis | Optional — degrades to in-memory if Redis is down at boot |
| `JWT_ACCESS_SECRET` | dev placeholder | Production boot **fails fast** on committed placeholders |
| `ACCESS_TOKEN_TTL_MINUTES` / `REFRESH_TOKEN_TTL_DAYS` / `RESET_TOKEN_TTL_MINUTES` | 15 / 30 / 30 | ADR 0011 |
| `PAYMENT_PROVIDER` | `sandbox` | Selects the adapter |
| `PAYMENT_WEBHOOK_SECRET` | dev placeholder | HMAC over the raw body |
| `PAYMENT_EXPIRATION_MINUTES` | 30 | ADR 0033 |
| `PUSH_PROVIDER` | `log` | `log` · `none` · `onesignal` (needs `ONESIGNAL_APP_ID`/`ONESIGNAL_API_KEY` or boot fails) |
| `SMTP_HOST` / `SMTP_PORT` / `EMAIL_FROM` | Mailpit | `SMTP_USER`/`SMTP_PASSWORD`/`SMTP_SECURE` for a real ESP relay |
| `METRICS_ENABLED` | unset (off) | Set with `METRICS_TOKEN` in production, or boot fails |
| `TRUST_PROXY` | `false` | `true` only behind Caddy — `req.ip` keys the auth rate-limit buckets |

`assertProductionConfig` (`env.validation.ts`) refuses to boot production on
placeholder secrets, a missing `SMTP_HOST`, `METRICS_ENABLED` without a token, or
`AUTH_RATE_LIMIT_DISABLED`.

## Testing

```bash
make test               # unit
make test-integration   # real PostgreSQL in Docker — SQLite is forbidden as a substitute
```

Integration tests run against a real `antrein_test` database because correctness
lives in DB constraints, not read-then-write checks. Required concurrency tests:
duplicate bookings, duplicate queue numbers, webhook idempotency.

## Troubleshooting

**API "running" but nothing answers on :3000.** Almost always the Node version.
`nest start --watch` compiles TypeScript fine on any Node, prints
`Watching for file changes`, spawns `node dist/main.js`, and that child
**segfaults instantly (exit 139) with zero output** when `argon2`'s native binary
does not match the running ABI. The watcher survives, so the terminal looks
healthy.

```bash
node -v                                  # v18 here is the bug
node -e "require('argon2')"; echo $?     # 139 = ABI mismatch
pgrep -fl "dist/main"                    # empty = the server is not running
lsof -iTCP:3000 -sTCP:LISTEN             # empty = nothing listening
```

Fix: `nvm use` (or `nvm alias default 22` to fix every future shell), then restart
`make dev`. An already-open terminal keeps its old `PATH` — open a new one or run
`nvm use default`.

**404 on `/api/v1/health/live`.** Wrong path — health is excluded from the global
prefix. Use `/health/live`.

**404 on `/realtime`.** Not a URL. Handshake against `/socket.io/`; `/realtime` is
the namespace.

**404 on `/api/v1/metrics`.** `METRICS_ENABLED` is unset by default, and a wrong
`METRICS_TOKEN` also returns 404 rather than 401.

**Typecheck fails on missing Prisma types.** The generated client is gitignored —
run `npx prisma generate`.

## Deployment

Self-hosted VPS: Caddy (TLS/WSS) + API + PostgreSQL in one Docker Compose stack —
see `docs/adr/0045-self-hosted-vps-deployment.md` for the topology and
`docs/ops/runbook.md` for setup, deploys, backups and incident playbooks.

```bash
# on the VPS, once deploy/ is copied and .env filled in
./deploy.sh          # pull → migrate → restart
```

Migrations are explicit (`docker compose run --rm migrate`), never on boot.
Backups are a nightly `pg_dump` with 14-day retention. Pushing to `main` builds
the image, scans it with Trivy, pushes to GHCR and runs `deploy.sh` over SSH
(`.github/workflows/deploy.yml`, gated on a `DEPLOY_HOST` repo variable).

## Documentation map

Conflict resolution order — higher wins for *what*, lower docs win for
implementation detail:

1. `docs/00-product-brief.md` — roles, journeys, business rules, status lifecycles, MVP scope
2. `docs/01-system-architecture.md` — system structure, module boundaries, deployment
3. `docs/02-api-contract.md` — every endpoint, WS event, error code, authorization matrix
4. `docs/backend/` — backend-brief, database-design, authentication, booking-payment, realtime-queue
5. `docs/frontend/` — flutter-brief, app-architecture, navigation-flow, state-management, ui-feature-spec

Decisions live in `docs/adr/` (0009–0045, all MVP open decisions resolved).
Business-rule changes update the relevant doc **before** the code.

Branching is gitflow: `main` (releases) ← `develop` ← `feature/*`.
