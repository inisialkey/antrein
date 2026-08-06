import 'package:antrein/core/config/app_config.dart';
import 'package:antrein/core/network/interceptors/auth_interceptor.dart';
import 'package:antrein/core/network/interceptors/logging_interceptor.dart';
import 'package:antrein/core/network/interceptors/refresh_interceptor.dart';
import 'package:antrein/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@module
abstract class NetworkModule {
  /// Bare Dio used only by the refresh flow — no interceptors, so a 401 during
  /// `/auth/refresh` cannot recurse back into [RefreshInterceptor].
  @Named('refreshDio')
  @lazySingleton
  Dio refreshDio(AppConfig config) =>
      Dio(_baseOptions(config))..interceptors.add(LoggingInterceptor());

  /// The app Dio: attaches the bearer token and refreshes-and-retries on 401.
  @lazySingleton
  Dio dio(
    AppConfig config,
    TokenStorage storage,
    @Named('refreshDio') Dio refreshDio,
  ) {
    final dio = Dio(_baseOptions(config));
    dio.interceptors.addAll([
      AuthInterceptor(storage),
      RefreshInterceptor(storage, dio, refreshDio),
      // Last, so the request line shows the headers actually sent. A 401 that
      // triggers a refresh is logged by the replayed request instead.
      LoggingInterceptor(),
    ]);
    return dio;
  }
}

/// 4xx is surfaced to `onResponse` (not `onError`) via `validateStatus`, so the
/// data layer reads the envelope and maps `error_code` to a typed exception.
BaseOptions _baseOptions(AppConfig config) => BaseOptions(
  baseUrl: config.apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 15),
  sendTimeout: const Duration(seconds: 15),
  contentType: Headers.jsonContentType,
  validateStatus: (code) => code != null && code < 500,
  headers: const {'Accept': 'application/json'},
);
