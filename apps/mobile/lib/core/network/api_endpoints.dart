/// Single registry of API paths, relative to `AppConfig.apiBaseUrl` (which
/// already carries the host + `/api/v1` prefix). Never hardcode a path literal
/// elsewhere — reference these. Use a method for parameterized paths.
abstract final class ApiEndpoints {
  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String passwordForgot = '/auth/password/forgot';
  static const String passwordReset = '/auth/password/reset';

  // Users
  static const String currentUser = '/me';

  // Health
  static const String health = '/health';

  /// Paths the `AuthInterceptor` must not attach a bearer token to — the
  /// unauthenticated endpoints. Logout and `/me` are protected (omitted here).
  static const Set<String> public = {
    register,
    login,
    refresh,
    passwordForgot,
    passwordReset,
    health,
  };
}
