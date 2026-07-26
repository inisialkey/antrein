import 'package:antrein/core/error/exceptions.dart';
import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/features/auth/data/models/auth_result.dart';
import 'package:antrein/features/auth/data/models/user_model.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResult> signIn({
    required String email,
    required String password,
    String? deviceId,
    String? platform,
  });

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  });

  Future<UserModel> getCurrentUser();

  /// Idempotent `PUT /me/devices/{deviceId}` (api-contract §34).
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    String? locale,
  });

  Future<void> signOut({String? refreshToken, String? deviceId});

  Future<void> requestPasswordReset({required String email});

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });
}

@LazySingleton(as: AuthRemoteDataSource)
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
    String? deviceId,
    String? platform,
  }) async {
    final data = await _send(
      () => _dio.post<dynamic>(
        ApiEndpoints.login,
        data: {
          'email': email,
          'password': password,
          // The nested device payload upserts the row and binds the session,
          // so logout can deactivate push for this phone (ADR 0039).
          if (deviceId != null && platform != null)
            'device': {'deviceId': deviceId, 'platform': platform},
        },
      ),
    );
    return AuthResult.fromJson(data);
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final data = await _send(
      () => _dio.post<dynamic>(
        ApiEndpoints.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phoneNumber': phoneNumber,
        },
      ),
    );
    return AuthResult.fromJson(data);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final data = await _send(() => _dio.get<dynamic>(ApiEndpoints.currentUser));
    return UserModel.fromJson(data);
  }

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    String? locale,
  }) async {
    await _send(
      () => _dio.put<dynamic>(
        ApiEndpoints.meDevice(deviceId),
        data: {'platform': platform, 'locale': ?locale},
      ),
    );
  }

  @override
  Future<void> signOut({String? refreshToken, String? deviceId}) async {
    await _send(
      () => _dio.post<dynamic>(
        ApiEndpoints.logout,
        // Null-aware map elements (Dart 3.8+): keys are omitted when null, so
        // logout falls back to bearer-only (LogoutDto fields are optional).
        data: {'refreshToken': ?refreshToken, 'deviceId': ?deviceId},
      ),
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _send(
      () => _dio.post<dynamic>(
        ApiEndpoints.passwordForgot,
        data: {'email': email},
      ),
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _send(
      () => _dio.post<dynamic>(
        ApiEndpoints.passwordReset,
        data: {'token': token, 'newPassword': newPassword},
      ),
    );
  }

  /// Runs a request, unwraps the `{ success, data, meta }` envelope, and maps an
  /// error envelope or transport failure to a typed [Exception].
  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return _unwrap(await request());
    } on DioException catch (error) {
      throw _mapTransportError(error);
    }
  }

  Map<String, dynamic> _unwrap(Response<dynamic> response) {
    final body = response.data;
    final status = response.statusCode ?? 0;
    if (status >= 200 &&
        status < 300 &&
        body is Map &&
        body['success'] == true) {
      final data = body['data'];
      return data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw _mapErrorCode(
      status: status,
      code: errorCodeOf(body),
      message: errorMessageOf(body),
    );
  }

  Exception _mapErrorCode({
    required int status,
    required String? code,
    required String message,
  }) {
    switch (code) {
      case ApiErrorCodes.authInvalidCredentials:
      case ApiErrorCodes.authAccessTokenInvalid:
      case ApiErrorCodes.authAccessTokenExpired:
      case ApiErrorCodes.authRefreshTokenInvalid:
      case ApiErrorCodes.authRefreshTokenExpired:
      case ApiErrorCodes.authRefreshTokenReused:
      case ApiErrorCodes.authSessionRevoked:
      case ApiErrorCodes.authAccountSuspended:
      case ApiErrorCodes.authAccountInactive:
      case ApiErrorCodes.authResetTokenInvalid:
      case ApiErrorCodes.authResetTokenExpired:
        return AuthException(message);
      case ApiErrorCodes.authEmailAlreadyRegistered:
        return ConflictException(message);
      case ApiErrorCodes.authPasswordReuseNotAllowed:
      case ApiErrorCodes.validationFailed:
        return ValidationException(message);
      case ApiErrorCodes.rateLimitExceeded:
        return RateLimitException(message);
      default:
        return status == 401
            ? AuthException(message)
            : ServerException(message);
    }
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
        );
    }
  }
}
