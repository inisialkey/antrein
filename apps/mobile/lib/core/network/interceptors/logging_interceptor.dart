import 'dart:convert';

import 'package:antrein/core/logging/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// HTTP tracing on top of [AppLogger].
///
/// Dio ships [LogInterceptor], but it prints raw headers and bodies — that puts
/// bearer tokens and plaintext passwords in the device log — so this one
/// redacts instead.
///
/// Failures log the [DioException.type] plus the underlying OS error, which is
/// the only way to tell "the device is offline" apart from "this host refused
/// the connection": Dio reports both as `connectionError`, and the UI cannot
/// distinguish them.
///
/// Verbose lines are `debug` level, so [AppLogger]'s filter drops them from
/// release builds; failures are `warning` and ship.
class LoggingInterceptor extends Interceptor {
  static const String _startKey = 'log_start_ms';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode) {
      AppLogger.d(
        '>> ${options.method} ${options.uri}\n'
        'headers: ${redactHeaders(options.headers)}\n'
        'body: ${redactBody(options.data)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final status = response.statusCode ?? 0;
    final line =
        '<< $status ${response.requestOptions.method} '
        '${response.requestOptions.uri} (${_elapsed(response.requestOptions)})';

    // 4xx lands here, not in [onError] (the app Dio uses
    // `validateStatus: (c) => c < 500`), so a rejected login would otherwise
    // leave no trace at all.
    if (status >= 400) {
      AppLogger.w('$line\nbody: ${redactBody(response.data)}');
    } else if (kDebugMode) {
      AppLogger.d('$line\nbody: ${redactBody(response.data)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.w(
      '!! ${err.requestOptions.method} ${err.requestOptions.uri} '
      '(${_elapsed(err.requestOptions)}) '
      'type=${err.type.name} status=${err.response?.statusCode}',
      error: err.error ?? err.message,
    );
    handler.next(err);
  }

  String _elapsed(RequestOptions options) {
    final start = options.extra[_startKey];
    return start is int
        ? '${DateTime.now().millisecondsSinceEpoch - start}ms'
        : '?';
  }
}

const int _maxBodyChars = 800;

const Set<String> _sensitiveHeaders = {
  'authorization',
  'cookie',
  'set-cookie',
};

const Set<String> _sensitiveFields = {
  'password',
  'currentpassword',
  'newpassword',
  'token',
  'accesstoken',
  'refreshtoken',
  'pushtoken',
};

@visibleForTesting
Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) => {
  for (final entry in headers.entries)
    entry.key: _sensitiveHeaders.contains(entry.key.toLowerCase())
        ? '<redacted>'
        : entry.value,
};

@visibleForTesting
String redactBody(dynamic data) {
  // A logging failure must never fail the request it is describing.
  try {
    if (data == null) return '<empty>';
    if (data is FormData) {
      return 'FormData(fields: ${data.fields.map((f) => f.key).toList()}, '
          'files: ${data.files.map((f) => f.key).toList()})';
    }
    final redacted = _redactValue(data);
    final text = redacted is Map || redacted is List
        ? jsonEncode(redacted, toEncodable: (o) => o.toString())
        : '$redacted';
    return text.length > _maxBodyChars
        ? '${text.substring(0, _maxBodyChars)}… (${text.length} chars)'
        : text;
  } on Object {
    return '<unloggable ${data.runtimeType}>';
  }
}

Object? _redactValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        '${entry.key}': _sensitiveFields.contains('${entry.key}'.toLowerCase())
            ? '<redacted>'
            : _redactValue(entry.value),
    };
  }
  if (value is List) return value.map(_redactValue).toList();
  return value;
}
