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

  // Business management (contract §43–§46). Creation posts to [businesses];
  // the service/staff list paths above are shared with public discovery — the
  // management screens just pass `activeOnly=false`.
  static String businessManagement(String businessId) =>
      '/businesses/$businessId/management';
  static String outletDetail(String businessId, String outletId) =>
      '/businesses/$businessId/outlets/$outletId';

  // Service management (§47–§49)
  static String serviceDetail(String businessId, String serviceId) =>
      '/businesses/$businessId/services/$serviceId';
  static String serviceDeactivate(String businessId, String serviceId) =>
      '/businesses/$businessId/services/$serviceId/deactivate';

  // Staff management (§50, §52, §53)
  static String staffInvitations(String businessId) =>
      '/businesses/$businessId/staff/invitations';
  static String staffDetail(String businessId, String staffId) =>
      '/businesses/$businessId/staff/$staffId';
  static String staffDeactivate(String businessId, String staffId) =>
      '/businesses/$businessId/staff/$staffId/deactivate';

  /// §51 — the invited user accepts from their own account, so this one is not
  /// business-scoped.
  static String staffInvitationAccept(String invitationId) =>
      '/staff/invitations/$invitationId/accept';

  // Schedule management (§54–§58.1)
  static String operatingHours(String businessId, String outletId) =>
      '/businesses/$businessId/outlets/$outletId/operating-hours';
  static String closedDates(String businessId, String outletId) =>
      '/businesses/$businessId/outlets/$outletId/closed-dates';
  static String staffSchedule(String businessId, String staffId) =>
      '/businesses/$businessId/staff/$staffId/schedule';

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

  // Notifications (contract §92–§95). The §93 single-get is omitted: the list
  // returns the full resource, so the inbox never needs to re-read one row.
  static const String notifications = '/notifications';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String notificationId) =>
      '/notifications/$notificationId/read';

  // Payments (contract §70, §74)
  static String bookingPayments(String bookingId) =>
      '/bookings/$bookingId/payments';
  static String paymentRefresh(String paymentId) =>
      '/payments/$paymentId/refresh';
  static String paymentRefunds(String businessId, String paymentId) =>
      '/businesses/$businessId/payments/$paymentId/refunds';

  // Files (contract §36–§37). The public §37.1 content route is never built
  // here — every image URL arrives absolute on the resource that owns it.
  static const String files = '/files';
  static String file(String fileId) => '/files/$fileId';

  // Current user (contract §32, §33)
  static const String me = '/me';
  static const String meNotificationPreferences =
      '/me/notification-preferences';

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
