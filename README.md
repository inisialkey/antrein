# AntreIn

Mobile-first booking, payment, check-in, and real-time queue platform for barbershops in Indonesia. Monorepo: NestJS API (`apps/api`) + Flutter app (`apps/mobile`).

## Prerequisites

- Node 22 (`.nvmrc`)
- Docker + Docker Compose

## Quickstart

```bash
nvm use            # or any Node 22
make bootstrap     # install deps, start postgres/redis/minio, migrate
make dev           # start the API in watch mode on :3000
```

API base: `http://localhost:3000/api/v1` · Health: `/health/live`, `/health/ready` · OpenAPI UI (non-prod): `/docs`

## Commands

| Command | What |
|---|---|
| `make bootstrap` | Install, start infra, migrate, generate Prisma client |
| `make dev` | Infra + API watch mode |
| `make test` | Backend unit tests |
| `make test-integration` | Integration tests against real PostgreSQL (`antrein_test`) |
| `make migrate` | Apply migrations |
| `make seed` | Seed development data |

## Documentation

Everything lives in `docs/` — start with `docs/00-product-brief.md`, `docs/01-system-architecture.md`, `docs/02-api-contract.md`. Decisions: `docs/adr/`.
