import 'package:antrein/core/error/exceptions.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/logging/app_logger.dart';
import 'package:antrein/core/storage/token_storage.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:antrein/features/auth/data/models/auth_result.dart';
import 'package:antrein/features/auth/domain/entities/user.dart';
import 'package:antrein/features/auth/domain/repositories/auth_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;

  @override
  ResultFuture<User> signIn({
    required String email,
    required String password,
  }) => _authenticate(
    () => _remote.signIn(email: email, password: password),
    'signIn',
  );

  @override
  ResultFuture<User> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  }) => _authenticate(
    () => _remote.register(
      name: name,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
    ),
    'register',
  );

  /// Shared path for sign-in and register: on success, persist the token pair
  /// before returning the user, so the very next authenticated request is armed.
  Future<Either<Failure, User>> _authenticate(
    Future<AuthResult> Function() action,
    String label,
  ) async {
    try {
      final result = await action();
      await _storage.saveTokens(
        accessToken: result.session.accessToken,
        refreshToken: result.session.refreshToken,
      );
      return Right(result.user.toEntity());
    } on Exception catch (e) {
      return Left(_mapFailure(e, label));
    }
  }

  @override
  ResultFuture<User> getCurrentUser() async {
    try {
      final model = await _remote.getCurrentUser();
      return Right(model.toEntity());
    } on Exception catch (e) {
      return Left(_mapFailure(e, 'getCurrentUser'));
    }
  }

  @override
  ResultVoid signOut() async {
    // Local logout always succeeds; the server revoke is best-effort.
    try {
      final refreshToken = await _storage.readRefreshToken();
      await _remote.signOut(refreshToken: refreshToken);
    } on Object catch (e) {
      AppLogger.w(
        'Server logout failed; clearing local session anyway',
        error: e,
      );
    }
    await _storage.clear();
    return const Right(null);
  }

  @override
  ResultVoid requestPasswordReset({required String email}) async {
    try {
      await _remote.requestPasswordReset(email: email);
      return const Right(null);
    } on Exception catch (e) {
      return Left(_mapFailure(e, 'requestPasswordReset'));
    }
  }

  @override
  ResultVoid resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _remote.resetPassword(token: token, newPassword: newPassword);
      return const Right(null);
    } on Exception catch (e) {
      return Left(_mapFailure(e, 'resetPassword'));
    }
  }

  Failure _mapFailure(Exception e, String label) => switch (e) {
    AuthException(:final message) => AuthFailure(message),
    ConflictException(:final message) => ConflictFailure(message),
    ValidationException(:final message) => ValidationFailure(message),
    RateLimitException(:final message) => RateLimitFailure(message),
    NetworkException(:final message) => NetworkFailure(message),
    ServerException(:final message) => ServerFailure(message),
    _ => _unexpected(e, label),
  };

  Failure _unexpected(Exception e, String label) {
    AppLogger.w('auth: unexpected exception in $label', error: e);
    return const ServerFailure('Unexpected error.');
  }
}
