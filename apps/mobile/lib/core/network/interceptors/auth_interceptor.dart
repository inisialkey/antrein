import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/storage/token_storage.dart';
import 'package:dio/dio.dart';

/// Attaches the `Authorization: Bearer <access>` header to protected requests.
/// Public auth endpoints are skipped so login/refresh never carry a stale token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final TokenStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublic(options.path) ||
        options.headers.containsKey('Authorization')) {
      return handler.next(options);
    }

    final token = await _storage.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  // Exact path match — `contains` would also exempt any path merely embedding
  // a public segment (e.g. `/users/auth/login-history`).
  bool _isPublic(String path) =>
      ApiEndpoints.public.contains(Uri.parse(path).path);
}
