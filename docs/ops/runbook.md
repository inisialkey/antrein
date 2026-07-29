# AntreIn Operations Runbook

Production topology, deploy procedure, and incident playbooks for the
self-hosted VPS stack (ADR 0045). Everything here assumes `deploy/` has been
copied to the VPS (default `/srv/antrein/deploy`) with a filled-in `.env`.

## 1. What runs where

| Piece | Where | Notes |
| --- | --- | --- |
| `caddy` | VPS container | TLS termination, HTTP→HTTPS, WSS for `/realtime` |
| `api` | VPS container | NestJS + all background jobs in-process (ADR 0045 §2) |
| `postgres` | VPS container, named volume `pgdata` | The only durable state |
| Redis | not deployed | Single instance; in-memory rate limits + fan-out |
| Object storage | not deployed | No `files` module exists yet |
| Push | OneSignal or `log` | `PUSH_PROVIDER` in `.env` |
| Email | ESP SMTP relay | `SMTP_*` in `.env` |

Background jobs inside the API container: payment expiration (60 s), outbox
dispatcher (2 s), payment reconciliation (5 min), consistency check (daily).

## 2. First-time setup

1. DNS: `A` record for `API_DOMAIN` → VPS IP (Caddy needs it before it can
   issue a certificate).
2. Install Docker Engine + compose plugin. Open ports 80 and 443 only; the
   database is never published beyond loopback.
3. `mkdir -p /srv/antrein && ` copy the repo's `deploy/` directory there.
4. `cp .env.prod.example .env`, fill every `CHANGE_ME` (`openssl rand -hex 32`),
   `chmod 600 .env`.
5. Make the GHCR package public (Packages → antrein-api → Change visibility), or
   `docker login ghcr.io -u <user>` with a read:packages PAT on the VPS.
6. `./deploy.sh` — pulls, migrates, starts. First run also issues the TLS cert.
7. Seed demo data (section 4).
8. GitHub repo settings for automated deploys:
   - Variables: `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_PATH`.
   - Secrets: `DEPLOY_SSH_KEY` (private key, deploy user), `DEPLOY_KNOWN_HOSTS`
     (`ssh-keyscan <host>`).
   The deploy job stays skipped until `DEPLOY_HOST` exists.

## 3. Deploy and roll back

Automatic: push to `main` → build → Trivy scan → GHCR push → SSH `deploy.sh`.

Manual: `ssh vps 'cd /srv/antrein/deploy && ./deploy.sh'`

Roll back to a known image:

```sh
API_IMAGE=ghcr.io/inisialkey/antrein-api:<sha> ./deploy.sh
```

Migrations are forward-only. A bad migration is fixed with a new migration, not
by rolling the image back onto a newer schema.

## 4. Demo data and database access

Postgres is published on loopback only, so reach it over SSH:

```sh
ssh -L 15432:127.0.0.1:5432 <user>@<host>          # keep open in one terminal
cd apps/api
DATABASE_URL=postgresql://antrein:<password>@localhost:15432/antrein npm run seed:demo
```

The seed is idempotent — re-run it any time to reset the demo catalog. It
prints the demo logins; the shared password is in `prisma/seed/demo.ts`.

`psql` shell on the box: `docker compose exec postgres psql -U antrein -d antrein`

## 5. Health, logs, metrics

```sh
docker compose ps
docker compose exec api wget -qO- http://127.0.0.1:3000/health/ready
docker compose logs -f --tail=100 api
```

`/health/live` = process up. `/health/ready` = database reachable **and** no
pending migrations; it answers 503 otherwise.

Metrics: `curl -H "Authorization: Bearer $METRICS_TOKEN" https://$API_DOMAIN/metrics`.
Counters worth watching:

| Counter | Meaning |
| --- | --- |
| `payment_webhook_total` / `_failure_total` / `_duplicate_total` | Provider callbacks |
| `payment_paid_total`, `payment_expired_total` | Payment outcomes |
| `payment_reconciliation_total` | Rows the 5-min job re-settled |
| `outbox_dispatched_total`, `queue_event_publish_failure_total` | Realtime delivery |
| `queue_check_in_total`, `queue_reorder_total`, `queue_version_conflict_total` | Queue activity |
| `consistency_violations_total` | Detector findings — investigate, never auto-repaired |

## 6. Backups

`deploy/backup.sh` runs `pg_dump --format=custom`, gzips into
`/var/backups/antrein`, and prunes past 14 days. Install as host cron:

```sh
0 3 * * * /srv/antrein/deploy/backup.sh >> /var/log/antrein-backup.log 2>&1
```

Restore (rehearse quarterly against a scratch database, never straight to prod):

```sh
gunzip -c /var/backups/antrein/antrein-<stamp>.dump.gz > /tmp/antrein.dump
docker compose exec -T postgres createdb -U antrein antrein_restore
docker compose exec -T postgres pg_restore -U antrein -d antrein_restore < /tmp/antrein.dump
```

A restore that has never been rehearsed is not a backup. Payment and audit rows
are the retention-critical tables (backend-brief §95).

## 7. Incident playbooks

### Payment stuck in `pending_payment`

Expected: the 60 s expiration job cancels it after 30 minutes; the 5 min
reconciliation job re-queries the provider first. Force a check without waiting:
`POST /api/v1/payments/{paymentId}/refresh` (same idempotent transition path as
the webhook). If the provider says paid but the reservation is gone, the payment
lands in `manual_review` and is auto-refunded — check `payment_events`.

### Refund stuck in `refund_pending`

Reconciliation re-requests it every 5 minutes (idempotent by refund id). Persisting
beyond an hour means the provider is rejecting it — read the API logs for the
refund id, then decide manually. Never edit refund rows by hand while the job runs.

### Outbox backlog

`SELECT status, count(*) FROM outbox_events GROUP BY status;`
Rows in `pending` with a rising `attempt_count` mean publishes are failing —
check `queue_event_publish_failure_total` and the WebSocket gateway logs.
Business state is already committed; realtime is catching up, and mobile clients
resync over REST regardless. Dead-lettered rows stay for inspection.

### Queue version conflicts

`QUEUE_VERSION_CONFLICT` is by design (ADR 0028) — two staff acted on the same
entry and the client resyncs. Only a sustained rise is a signal, usually a stuck
client polling with a stale version.

### Consistency violations logged

The daily job only detects (booking-payment §82): orphan/missing reservations,
queue↔booking terminal mismatches, stale refunds, outbox backlog. Read the log
line, confirm against the tables, repair by hand in a transaction. It must never
be made to auto-repair.

### API container unhealthy

```sh
docker compose logs --tail=200 api
docker compose restart api
```

Boot failures are almost always configuration: production env validation refuses
placeholder secrets, a missing `SMTP_HOST`, `METRICS_ENABLED` without a token,
or `PUSH_PROVIDER=onesignal` without credentials. The message names the variable.

### Database down

`/health/ready` reports 503 and the API stays up (it reconnects lazily). Check
`docker compose logs postgres` and disk space (`df -h`) — a full volume is the
usual cause on a small VPS.

### Password-reset emails not arriving

The API logs SMTP failures from `SmtpEmailService`. Verify `SMTP_*` in `.env`,
that the ESP domain is verified, and that `EMAIL_FROM` matches it.

## 8. Secret rotation

| Secret | Effect of rotating | Steps |
| --- | --- | --- |
| `JWT_ACCESS_SECRET` | Every access token invalid immediately; refresh tokens survive (opaque, DB-stored), so clients recover on their next refresh | edit `.env`, `docker compose up -d api` |
| `PAYMENT_WEBHOOK_SECRET` | Provider callbacks fail signature until the provider dashboard is updated | rotate in the provider first, then `.env` |
| `POSTGRES_PASSWORD` | Requires `ALTER ROLE` + `DATABASE_URL` update in the same maintenance window | `ALTER ROLE antrein WITH PASSWORD '…'`, edit `.env`, restart api |
| `METRICS_TOKEN` | Scrapers 404 until updated | edit `.env`, restart api |
| `DEPLOY_SSH_KEY` | CI cannot deploy until the new public key is in `~/.ssh/authorized_keys` | add new key, update secret, remove old key |

Rotating a secret always ends with `docker compose up -d api` and a
`/health/ready` check.

## 9. Total loss recovery

1. Provision a VPS, install Docker, point DNS at it.
2. Copy `deploy/` + the `.env` from the password manager.
3. `docker compose up -d postgres`, restore the newest dump (section 6) into
   `antrein`.
4. `./deploy.sh` — migrations are idempotent, so a restored database that is
   already current is a no-op.
5. Verify `/health/ready`, then a login and a booking from the app.

## 10. Staging

Staging is the same stack in a second compose project on the same box — copy
`deploy/` to `/srv/antrein-staging/deploy` with its own `.env`
(`API_DOMAIN=staging.<domain>`, its own database credentials and volume names
via `docker compose -p antrein-staging`), and deploy from a branch image tag:

```sh
API_IMAGE=ghcr.io/inisialkey/antrein-api:<sha> docker compose -p antrein-staging \
  -f docker-compose.prod.yml up -d
```

Use it to rehearse a migration before it reaches production (§93 "migration
rehearsal"). It is deliberately not wired into CI: a solo demo does not need an
automatic staging deploy on every push, and the manual command is the rehearsal.

Load testing is likewise not automated. Concurrency correctness — duplicate
bookings, duplicate queue numbers, webhook idempotency — is covered by the
integration suite, which is the part that would actually corrupt data. Throughput
numbers for one VPS container would measure the box, not the code.

## 11. When one instance stops being enough

In order: add the Redis service and set `REDIS_URL` (Socket.IO fan-out + shared
rate limits), then run a second `api` container behind Caddy, then split the
worker out (needs a `worker.js` entrypoint and a job-enable flag — ADR 0045 §2).
Nothing else in the stack changes.
