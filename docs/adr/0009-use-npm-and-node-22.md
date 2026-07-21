# ADR 0009 — Use npm and Node 22 LTS

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

No package manager or Node version is specified anywhere in the docs (flagged as an open decision). The backend is a single NestJS app; there is no workspace-level dependency sharing between `apps/api` (TypeScript) and `apps/mobile` (Dart), so monorepo package-manager features (pnpm workspaces, turborepo) add nothing today.

Numbering note: ADRs 0001–0008 are reserved for the already-made architecture decisions listed in `docs/01-system-architecture.md` §71; they are fully documented there and may be backfilled as records later. New decisions start at 0009.

## Decision

- Package manager: **npm** (lockfile `package-lock.json`, CI installs with `npm ci`).
- Node version: **22 LTS**, pinned via `.nvmrc` at repo root and `node-version: 22` in CI.

## Alternatives

- pnpm: faster installs, workspace support — no workspace need exists; adds a toolchain requirement for zero current benefit.
- Node 24: newer LTS, but 22 has the longest remaining active support overlap with current NestJS/Prisma support matrices.

## Consequences

- Revisit only if a shared TypeScript package appears in `packages/` (then pnpm workspaces becomes worth it).
- Engines field in `apps/api/package.json` enforces the floor.
