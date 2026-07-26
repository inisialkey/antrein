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
  static String meDevice(String deviceId) => '/me/devices/$deviceId';

  // Discovery (public — ADR 0022)
  static const String businesses = '/businesses';
  static String businessDetail(String businessId) => '/businesses/$businessId';
  static String businessServices(String businessId) =>
      '/businesses/$businessId/services';
  static String businessStaff(String businessId) =>
      '/businesses/$businessId/staff';
  static String businessAvailability(String businessId) =>
      '/businesses/$businessId/availability';

  // Bookings (customer)
  static const String bookings = '/bookings';
  static String bookingDetail(String bookingId) => '/bookings/$bookingId';
  static String bookingCancel(String bookingId) =>
      '/bookings/$bookingId/cancel';
  static String checkIn(String bookingId) => '/bookings/$bookingId/check-in';
  static String customerQueue(String bookingId) => '/bookings/$bookingId/queue';

  // Business queue (staff — contract §82–§90)
  static String outletQueue(String businessId, String outletId) =>
      '/businesses/$businessId/outlets/$outletId/queue';
  static String queueCommand(
    String businessId,
    String queueEntryId,
    String action,
  ) => '/businesses/$businessId/queue/$queueEntryId/$action';

  // Payments
  static String paymentRefresh(String paymentId) =>
      '/payments/$paymentId/refresh';

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
