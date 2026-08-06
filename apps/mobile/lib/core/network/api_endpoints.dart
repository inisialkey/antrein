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
  static String bookingReview(String bookingId) =>
      '/bookings/$bookingId/review';

  // Reports (business — contract §98)
  static String dailySummary(String businessId) =>
      '/businesses/$businessId/reports/daily-summary';

  // Business queue (staff — contract §67, §82–§90)
  static String outletQueue(String businessId, String outletId) =>
      '/businesses/$businessId/outlets/$outletId/queue';
  static String queueCommand(
    String businessId,
    String queueEntryId,
    String action,
  ) => '/businesses/$businessId/queue/$queueEntryId/$action';
  static String walkIns(String businessId) =>
      '/businesses/$businessId/walk-ins';
  static String queueReorder(String businessId, String outletId) =>
      '/businesses/$businessId/outlets/$outletId/queue/reorder';

  // Business bookings (staff — contract §65, §68, §68.1, §73). The §66 single-get
  // is omitted: the list already returns the full business-view resource, so the
  // detail sheet reads from the loaded page. Add it when the sheet outlives a list.
  static String businessBookings(String businessId) =>
      '/businesses/$businessId/bookings';
  static String businessBookingCancel(String businessId, String bookingId) =>
      '/businesses/$businessId/bookings/$bookingId/cancel';
  static String businessBookingNoShow(String businessId, String bookingId) =>
      '/businesses/$businessId/bookings/$bookingId/no-show';
  static String payAtLocationConfirm(String businessId, String bookingId) =>
      '/businesses/$businessId/bookings/$bookingId/payments/pay-at-location/confirm';

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
