import 'package:antrein/features/auth/data/models/session_tokens_model.dart';
import 'package:antrein/features/auth/data/models/user_model.dart';

/// The data-layer result of a successful sign-in/register: the user plus the
/// token pair the repository persists to secure storage. Parsed from the
/// `data: { user, session }` envelope payload.
class AuthResult {
  const AuthResult({required this.user, required this.session});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    user: UserModel.fromJson((json['user'] as Map).cast<String, dynamic>()),
    session: SessionTokensModel.fromJson(
      (json['session'] as Map).cast<String, dynamic>(),
    ),
  );

  final UserModel user;
  final SessionTokensModel session;
}
