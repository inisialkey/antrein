import 'package:antrein/core/error/exceptions.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:dio/dio.dart';

/// Shared envelope unwrapping for feature data sources beyond auth: runs the
/// request, unwraps `{ success, data, meta }`, and maps error envelopes and
/// transport failures to typed exceptions carrying the stable `error.code`.
/// (Auth keeps its own copy with auth-specific code mapping.)
Future<Map<String, dynamic>> sendEnvelope(
  Future<Response<dynamic>> Function() request,
) async {
  final Response<dynamic> response;
  try {
    response = await request();
  } on DioException catch (error) {
    throw mapTransportError(error);
  }

  final body = response.data;
  final status = response.statusCode ?? 0;
  if (status >= 200 && status < 300 && body is Map && body['success'] == true) {
    final data = body['data'];
    return data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
  }
  throw mapEnvelopeError(
    status: status,
    code: errorCodeOf(body),
    message: errorMessageOf(body),
  );
}

/// Some list envelopes hoist pagination into `meta` — when a caller needs it,
/// use this variant which returns the whole decoded body.
Future<Map<String, dynamic>> sendEnvelopeRaw(
  Future<Response<dynamic>> Function() request,
) async {
  final Response<dynamic> response;
  try {
    response = await request();
  } on DioException catch (error) {
    throw mapTransportError(error);
  }
  final body = response.data;
  final status = response.statusCode ?? 0;
  if (status >= 200 && status < 300 && body is Map && body['success'] == true) {
    return body.cast<String, dynamic>();
  }
  throw mapEnvelopeError(
    status: status,
    code: errorCodeOf(body),
    message: errorMessageOf(body),
  );
}

/// Generic status/code → exception mapping for non-auth features. The concrete
/// backend code rides along so the presentation layer can localize known cases.
Exception mapEnvelopeError({
  required int status,
  required String? code,
  required String message,
}) {
  if (code == ApiErrorCodes.validationFailed) {
    return ValidationException(message, code: code);
  }
  if (code == ApiErrorCodes.rateLimitExceeded || status == 429) {
    return RateLimitException(message, code: code);
  }
  return switch (status) {
    401 => AuthException(message, code: code),
    409 => ConflictException(message, code: code),
    422 => ValidationException(message, code: code),
    _ => ServerException(message, code: code),
  };
}

/// Transport (no HTTP response) → typed exception, shared by every data source.
///
/// `connectionError` covers a refused, unroutable or unresolvable host just as
/// much as a device with no network, so the message must not claim the device
/// is offline — a reachable phone pointed at a stopped API hits this too. The
/// distinguishing detail (OS error, host, port) goes to the log, not the UI:
/// see `LoggingInterceptor`.
Exception mapTransportError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkException('The request timed out.');
    case DioExceptionType.connectionError:
      return const NetworkException(
        'Cannot reach the server. Check your connection and try again.',
      );
    case DioExceptionType.badResponse:
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return ServerException(
        errorMessageOf(error.response?.data, fallback: 'Server error.'),
        code: errorCodeOf(error.response?.data),
      );
  }
}
