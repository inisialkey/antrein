import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// App-wide logging facade over the `logger` package.
///
/// Use this instead of `print` / `debugPrint` / a raw `Logger`. Release builds
/// drop everything below `warning`, so debug noise never ships. The SDK lives
/// only here — call sites depend on `AppLogger`, not `logger`.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    filter: _AppLogFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      printEmojis: false,
    ),
  );

  static void t(String message) => _logger.t(message);

  static void d(String message) => _logger.d(message);

  static void i(String message) => _logger.i(message);

  static void w(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  static void e(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}

class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) =>
      !kReleaseMode || event.level.value >= Level.warning.value;
}
