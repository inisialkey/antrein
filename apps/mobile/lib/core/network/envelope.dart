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
    throw _mapTransportError(error);
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
    throw _mapTransportError(error);
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

Exception _mapTransportError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const NetworkException('The request timed out.');
    case DioExceptionType.connectionError:
      return const NetworkException('No internet connection.');
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
