import 'package:antrein/core/logging/app_logger.dart';
import 'package:antrein/core/observability/crash_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// The only [CrashReporter] binding for the MVP — logs to the console and sends
/// nothing. Registered for every environment; a real backend (Sentry/Crashlytics)
/// is deferred, so swapping in an adapter later only touches DI, not call sites.
@LazySingleton(as: CrashReporter)
class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
  }) async {
    AppLogger.d('[crash:noop] fatal=$fatal: $error');
  }

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) async {}

  @override
  void setUser({required String id}) {}

  @override
  Future<void> addBreadcrumb(String message) async {}
}
