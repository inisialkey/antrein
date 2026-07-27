/// Named routes. `go_router` uses named navigation only (never raw path
/// literals at call sites). Customer tabs live under the customer shell; the
/// business shell is a single stub route until M4.
enum Routes {
  // Auth flow
  login('/login'),
  register('/register'),
  forgotPassword('/forgot-password'),
  resetPassword('/reset-password'),

  // Customer shell tabs
  customerHome('/home'),
  customerBookings('/bookings'),
  customerNotifications('/notifications'),
  customerProfile('/profile'),

  // Booking flow (full-screen, outside the shell)
  businessDetail('/business/:businessId'),
  bookingSlots('/book/slots'),
  bookingConfirm('/book/confirm'),
  bookingDetail('/booking/:bookingId'),
  customerQueue('/queue/:bookingId'),

  // Business shell (stub until M4)
  businessHome('/business'),
  businessReports('/business/reports/:businessId/:outletId');

  const Routes(this.path);

  final String path;
}
