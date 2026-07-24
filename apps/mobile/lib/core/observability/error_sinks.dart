import 'dart:async';

import 'package:antrein/core/observability/crash_reporter.dart';
import 'package:flutter/foundation.dart';

/// Installs the framework + platform error sinks, routing both through the
/// injected [CrashReporter]. Extracted from bootstrap so the wiring is unit
/// testable. The third sink (zone-escaped errors) is the `runZonedGuarded`
/// handler in bootstrap, which must wrap `runApp`.
void installErrorSinks(CrashReporter reporter) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(reporter.recordFlutterError(details));
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reporter.recordError(error, stack, fatal: true));
    return true;
  };
}
