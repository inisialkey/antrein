# ADR 0043 — Mobile API integration: hand-written datasources over a generated client

- **Status:** Accepted
- **Date:** 2026-07-24

`docs/frontend/app-architecture.md` §14 and the CLAUDE.md "contract flow" specify
a **generated Dart client** from `packages/api-contracts/openapi/antrein-v1.json`,
wrapped behind repositories. The reference boilerplate adopted in ADR 0042 instead
**hand-writes** data sources with Dio, `freezed`/`json_serializable` models, and an
`ApiEndpoints` registry.

**Decision:** follow the boilerplate. For the MVP the mobile app uses hand-written
`RemoteDataSource`s (e.g. `AuthRemoteDataSource`), `freezed` wire models mapped to
domain entities via `toEntity()`, and single registries `ApiEndpoints` (paths) and
`ApiErrorCodes` (stable `error.code` values mirroring `apps/api` `auth.errors.ts`).
**No OpenAPI→Dart client is generated.**

This **reverses** app-architecture §14 / the contract-flow "generated Dart client"
and **supersedes ADR 0032's "committed Dart client"** as to the client artifact.
The OpenAPI JSON and `docs/02-api-contract.md` remain the authoritative contract;
only the mechanism for consuming it on the client changes.

**Rationale:**

- Consistency with the declared architecture source of truth (ADR 0042).
- The auth surface is thin; a codegen toolchain (generator, version pinning, CI
  compile step) is not justified yet.
- The invariant the generated-client rule protected — *generated DTOs never reach
  the UI* — is preserved differently: the data layer maps every wire model to a
  domain entity, and the envelope→typed-exception→`Failure` pipeline keeps Dio and
  raw JSON out of `domain`/`presentation` (CI-enforced, ADR 0042).

**Consequences:** contract-drift risk is mitigated by (a) `ApiEndpoints` /
`ApiErrorCodes` mirroring the backend, and (b) contract tests that parse real
response envelopes. Revisit — and reconsider generation — if the consumed endpoint
surface grows large (M4+).
