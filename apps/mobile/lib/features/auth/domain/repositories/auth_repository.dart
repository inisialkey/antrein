import 'package:antrein/core/error/failures.dart' show Failure;
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/auth/domain/entities/user.dart';

/// Auth domain port. Implementations persist the token pair on sign-in/register
/// and clear it on sign-out; the presentation layer only ever sees [User] or a
/// [Failure].
abstract class AuthRepository {
  ResultFuture<User> signIn({required String email, required String password});

  ResultFuture<User> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  });

  ResultVoid signOut();

  /// Best-effort re-registration of this device's push token, for when the
  /// OneSignal subscription id arrives after sign-in. Always resolves Right.
  ResultVoid syncDevice();

  ResultFuture<User> getCurrentUser();

  ResultVoid requestPasswordReset({required String email});

  ResultVoid resetPassword({
    required String token,
    required String newPassword,
  });
}
