# ADR 0045 — Demo hosting: self-hosted VPS, single Docker Compose stack

- **Status:** Accepted
- **Date:** 2026-07-29

## Context

B10 / M9 (production readiness) is the last milestone, and it was blocked on the
only remaining open decision: where the demo runs. Everything downstream —
Dockerfile shape, migration procedure, TLS/WSS termination, backups, the real
ESP deferred by ADR 0037, and the mobile flavors' `API_BASE_URL` — depends on it.

Constraints: one solo portfolio deployment, one instance, no autoscaling, no
Kubernetes, no paid managed platform. A VPS the author already owns is the
cheapest option that still satisfies backend-brief §93 production requirements
(HTTPS/WSS, managed secrets, backups, monitoring, controlled migrations).

## Decision

1. **Host: an owned cloud VPS running `docker-compose.prod.yml`.** Services:
   `caddy` (reverse proxy, automatic Let's Encrypt certificates for HTTPS and
   WSS), `api`, `postgres` (named volume), plus a one-shot `migrate` service
   behind a compose profile. No PaaS, no orchestrator.

2. **One image, one running API container — the worker stays inline.** This
   amends ADR 0035, which planned a separate worker container for staging and
   production. `WORKER_MODE` was never implemented (it is not in
   `env.validation.ts`); the jobs — `PaymentExpirationJob`,
   `OutboxDispatcherJob`, `PaymentReconciliationJob`, `ConsistencyCheckJob` —
   simply run in-process and are skipped only under `NODE_ENV=test`. A second
   container from the same image would run every one of them a second time. The
   outbox is safe under that (`FOR UPDATE SKIP LOCKED`), but the sweeps would
   double their provider calls for zero benefit at this volume. Splitting the
   worker is a code change (a `worker.js` entrypoint plus a job-enablement flag),
   not a deployment flag, and it is deferred until a second instance is needed.

3. **Redis stays out of the production stack.** ADR 0036 makes it mandatory only
   above one instance. Rate limiting is in-memory and correct for one process;
   the Socket.IO Redis adapter is already wired behind `REDIS_URL` and boots
   with in-memory fan-out when unset. Adding the service is a two-line compose
   change on the day a second instance exists.

4. **Object storage is not deployed.** No `files` module exists in the codebase,
   so MinIO stays a local-only compose service and `ObjectStoragePort` remains a
   planned port. The production stack gets it when file uploads ship.

5. **Migrations are explicit, never on boot.** `docker compose run --rm migrate`
   (same image, `npx prisma migrate deploy`) runs before the API is restarted,
   satisfying "controlled migrations" (§93). One image covers both roles because
   `@prisma/client@7` depends on the `prisma` CLI, so it survives
   `npm prune --omit=dev` in the runtime stage — no second image, no CLI moved
   into `dependencies` by hand.

6. **Email closes ADR 0037 with SMTP-relay credentials, not an SDK.** The
   deployed stack points the existing `SmtpEmailService` at any ESP's SMTP relay
   (Resend, Brevo, SES, Postmark all expose one) via new
   `SMTP_USER` / `SMTP_PASSWORD` / `SMTP_SECURE` variables. Authentication is
   applied only when `SMTP_USER` is set, so Mailpit keeps working locally with
   no branch in the adapter and no provider SDK dependency.

7. **Release flow:** `main` → GitHub Actions builds and pushes
   `ghcr.io/<owner>/antrein-api:<sha>` → Trivy scans the image → SSH to the VPS
   → `docker compose pull`, run `migrate`, `up -d`. Secrets live in a
   root-owned `.env` on the VPS (never in the image, never in the repo).

8. **Backups are `pg_dump` on host cron** (`scripts/backup.sh`, daily, 14-day
   retention) with a documented restore rehearsal in the runbook. Point-in-time
   recovery (§95) is out of scope for a demo; the retention/rehearsal pair is
   the minimum that makes a restore real rather than theoretical.

## Consequences

- The whole production topology is one file the author can read, plus a runbook.
  Recovery from total VPS loss is: provision, clone, `.env`, restore dump, `up`.
- Availability is single-instance. Deploys have a short restart gap; the mobile
  client already resyncs over REST after a WebSocket drop, so the visible cost
  is a reconnect.
- The scale-out path stays exactly as documented: add Redis, add instances, then
  extract the worker (2) and flip rate limiting to Redis.
- Rejected: **Fly.io / Railway / Render** (recurring cost or sleeping free tiers,
  and a platform-specific manifest to maintain for one demo); **Kubernetes**
  (an order of magnitude more moving parts than one container needs);
  **auto-migrate on container start** (a failed migration would then take the
  API down with it, and a rollback would race the restart loop).
