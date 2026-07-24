import 'package:antrein/core/logging/app_logger.dart';
import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/core/storage/token_storage.dart';
import 'package:dio/dio.dart';

/// Transparently refreshes an expired access token and retries the failed call.
///
/// On a `401` access-token error from a protected endpoint it rotates the token
/// pair via [_refreshDio] (a bare Dio with no interceptors, to avoid recursion),
/// then replays the original request with the new access token. A failed refresh
/// (`AUTH_REFRESH_TOKEN_*` / `AUTH_SESSION_REVOKED`, or no stored token) clears
/// the session so the app router redirects to login.
///
/// Extends [QueuedInterceptor] so concurrent 401s serialize — only one refresh
/// runs; the queued requests then replay with the already-rotated token.
///
/// Note: because the app Dio uses `validateStatus: (c) => c < 500`, a 401 is
/// delivered to [onResponse] (not [onError]) carrying the error envelope, so the
/// trigger is read from `error.code`, not from a thrown [DioException].
class RefreshInterceptor extends QueuedInterceptor {
  RefreshInterceptor(this._storage, this._retryDio, this._refreshDio);

  final TokenStorage _storage;
  // Replays the original request (full app interceptor chain).
  final Dio _retryDio;
  // Bare Dio for `/auth/refresh` only — no interceptors, so it can't recurse.
  final Dio _refreshDio;

  static const String _retriedKey = 'auth_retried';

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (!_shouldAttemptRefresh(response)) {
      return handler.next(response);
    }

    final usedToken = _bearerOf(response.requestOptions);
    final currentToken = await _storage.readAccessToken();

    // A concurrent request already rotated the token — just replay.
    if (currentToken != null && currentToken != usedToken) {
      return _replay(response.requestOptions, currentToken, handler, response);
    }

    final refreshed = await _refresh();
    if (!refreshed) {
      await _storage.clear();
      return handler.next(response);
    }

    final newToken = await _storage.readAccessToken();
    if (newToken == null) {
      return handler.next(response);
    }
    return _replay(response.requestOptions, newToken, handler, response);
  }

  bool _shouldAttemptRefresh(Response<dynamic> response) {
    if (response.statusCode != 401) return false;
    if (response.requestOptions.extra[_retriedKey] == true) return false;

    final path = Uri.parse(response.requestOptions.path).path;
    if (path == ApiEndpoints.refresh || path == ApiEndpoints.login) {
      return false;
    }

    return ApiErrorCodes.refreshable.contains(errorCodeOf(response.data));
  }

  Future<bool> _refresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _refreshDio.post<dynamic>(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );
      final body = response.data;
      if (response.statusCode == 200 &&
          body is Map &&
          body['success'] == true) {
        final data = (body['data'] as Map).cast<String, dynamic>();
        await _storage.saveTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
        return true;
      }
      return false;
    } on Object catch (e) {
      AppLogger.w('token refresh failed', error: e);
      return false;
    }
  }

  Future<void> _replay(
    RequestOptions request,
    String token,
    ResponseInterceptorHandler handler,
    Response<dynamic> fallback,
  ) async {
    try {
      final retried = await _retryDio.request<dynamic>(
        request.path,
        data: request.data,
        queryParameters: request.queryParameters,
        cancelToken: request.cancelToken,
        options: Options(
          method: request.method,
          headers: {...request.headers, 'Authorization': 'Bearer $token'},
          extra: {...request.extra, _retriedKey: true},
          responseType: request.responseType,
          contentType: request.contentType,
          sendTimeout: request.sendTimeout,
          receiveTimeout: request.receiveTimeout,
        ),
      );
      return handler.resolve(retried);
    } on DioException catch (error) {
      return handler.next(error.response ?? fallback);
    } on Object {
      return handler.next(fallback);
    }
  }

  String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is String && header.startsWith('Bearer ')) {
      return header.substring(7);
    }
    return null;
  }
}
