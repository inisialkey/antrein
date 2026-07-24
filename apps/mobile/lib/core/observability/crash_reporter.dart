import 'package:flutter/foundation.dart';

/// Domain port for crash/error reporting. Pure — no Sentry/Crashlytics import.
/// The SDK type lives only in an adapter; app code depends on this contract.
abstract class CrashReporter {
  /// Initialise the backend SDK once, in bootstrap, before installing sinks.
  /// No-op for stand-in adapters.
  Future<void> initialize();

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal,
  });

  Future<void> recordFlutterError(FlutterErrorDetails details);

  void setUser({required String id});

  Future<void> addBreadcrumb(String message);
}
