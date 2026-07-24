import 'dart:async';

import 'package:antrein/core/config/app_config.dart';
import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/feature_flags/feature_flag_service.dart';
import 'package:antrein/core/observability/crash_reporter.dart';
import 'package:antrein/core/observability/error_sinks.dart';
import 'package:antrein/core/router/app_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:intl/date_symbol_data_local.dart';

/// One bootstrap for every flavor: resolve config → wire DI → install error
/// sinks → warm flags + restore session behind the splash → runApp. A remote
/// crash/analytics backend is deferred (the CrashReporter is a no-op), so there
/// is no Firebase/Sentry init here yet.
Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  final flavor = AppConfig.fromEnvironment().flavor;
  await configureDependencies(flavor.name);

  final reporter = getIt<CrashReporter>();

  await runZonedGuarded(
    () async {
      final binding = WidgetsFlutterBinding.ensureInitialized();
      // Hold the native splash through async init so launch shows the splash,
      // not a blank frame. Removed once the app is mounted.
      FlutterNativeSplash.preserve(widgetsBinding: binding);
      await initializeDateFormatting('id_ID');

      await reporter.initialize();
      installErrorSinks(reporter);

      // Warm feature flags before first frame, but never block launch on it.
      await getIt<FeatureFlagService>().initialize().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );

      // Restore an existing session before first frame so a returning user
      // lands on the home shell, not login. The splash covers the `/me`
      // round-trip; never block launch on it (e.g. the API is down).
      await getIt<AppRouter>().authCubit.restoreSession().timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );

      runApp(await builder());
      // App tree mounted — allow the first frame and close the native splash.
      FlutterNativeSplash.remove();
    },
    (error, stack) =>
        unawaited(reporter.recordError(error, stack, fatal: true)),
  );
}
