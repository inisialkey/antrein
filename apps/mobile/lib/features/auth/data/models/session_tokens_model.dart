/// Data-layer view of the API `session` object: the token pair plus ISO-8601
/// expiry timestamps (camelCase contract). The MVP refresh flow is reactive
/// (triggered by a 401), so only the tokens are persisted; the expiries are
/// parsed for completeness and future proactive-refresh use.
class SessionTokensModel {
  const SessionTokensModel({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  factory SessionTokensModel.fromJson(Map<String, dynamic> json) =>
      SessionTokensModel(
        accessToken: json['accessToken'] as String,
        accessTokenExpiresAt: json['accessTokenExpiresAt'] as String,
        refreshToken: json['refreshToken'] as String,
        refreshTokenExpiresAt: json['refreshTokenExpiresAt'] as String,
      );

  final String accessToken;
  final String accessTokenExpiresAt;
  final String refreshToken;
  final String refreshTokenExpiresAt;
}
