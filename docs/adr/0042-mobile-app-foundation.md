# ADR 0042 — Mobile app foundation: adopt the reference Flutter boilerplate

- **Status:** Accepted
- **Date:** 2026-07-24

M3 bootstraps `apps/mobile`. The owner designated their Flutter boilerplate
(`github.com/inisialkey/ai-workflow-flutter-sample`) the **source of truth for
mobile architecture, structure, style, and conventions** — reuse and extend it,
don't refactor or introduce new patterns; consistency over novelty. (The backend
remains source of truth for the API *contract*.)

**Decisions:**

- **Port the boilerplate core verbatim**, package renamed `reference_app → antrein`:
  feature-first Clean Architecture (`data`/`domain`/`presentation`, `domain` pure
  Dart); `flutter_bloc` Cubit + sealed `freezed` states; `get_it` + `injectable`
  codegen; `fpdart` `Either<Failure, T>` (`ResultFuture`); sealed `Failure` +
  `*Exception` pairs; `UseCase<Out,Params>`; `go_router` with a singleton
  `AppRouter` holding the app-lifetime `AuthCubit` + `GoRouterRefreshStream` +
  pure `resolveAuthRedirect`; `dio` two-client pattern (bare `refreshDio` + app
  `dio`) with `AuthInterceptor` and a `QueuedInterceptor`-based single-flight
  `RefreshInterceptor`, `validateStatus: <500` so 4xx envelopes are mapped to
  typed exceptions; `flutter_secure_storage` `TokenStorage`; Material 3 theme +
  `AppPalette` extension; `flutter_screenutil`; gen-l10n (`id` + `en`);
  `AppLogger`; `very_good_analysis`.
- **Pin Flutter 3.44.4 / Dart 3.12.2** (resolves the CLAUDE.md open decision).
  Package versions pinned in `apps/mobile/pubspec.yaml`.
- **Three flavors** `dev`/`staging`/`production` via `main_<flavor>.dart` +
  `AppConfig.fromEnvironment()` + `--dart-define-from-file config/flavors/*.json`.
  Native per-flavor bundle-id/scheme wiring is **deferred** — `--dart-define-from-file`
  runs without it (`ponytail:` revisit in hardening).
- **Observability trimmed for MVP:** the `CrashReporter` and `FeatureFlagService`
  ports are kept, but with the `Noop`/`Local` implementations registered for
  **every** environment. The Sentry and Firebase Remote Config adapters — and the
  `sentry_flutter` / `firebase_core` / `firebase_remote_config` dependencies — are
  dropped until a real backend is provisioned. Re-adding one then touches DI only.
- **`import_lint` deferred:** layer-boundary purity is enforced by a Mobile CI
  grep gate plus `very_good_analysis`, not the analyzer plugin.

**Consequences:** maximum fidelity to the boilerplate with minimal bespoke code;
the auth vertical slice (M3) follows the boilerplate's own auth feature 1:1,
adapted only where the AntreIn contract differs (see ADR 0043). Two-shell
role-aware navigation (customer live, business stub) is the one deliberate
*extension* over the boilerplate's flat routes, sized for M4.
