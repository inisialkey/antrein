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

  // Booking flow (full-screen, outside the shell). Public discovery detail —
  // the plural path keeps it clear of the `/business/*` shell gate, which sends
  // anyone without business access back to the customer home.
  businessDetail('/businesses/:businessId'),
  bookingSlots('/book/slots'),
  bookingConfirm('/book/confirm'),
  bookingDetail('/booking/:bookingId'),
  customerQueue('/queue/:bookingId'),

  // Business shell
  businessHome('/business'),
  businessBookings('/business/bookings/:businessId/:outletId'),
  businessReports('/business/reports/:businessId/:outletId'),
  businessServices('/business/services/:businessId'),
  businessStaff('/business/staff/:businessId/:outletId'),
  businessSchedule('/business/schedule/:businessId/:outletId'),
  businessSettings('/business/settings/:businessId/:outletId'),

  // Account settings, pushed over the customer shell's Profile tab. Kept off
  // `/profile/*` so they can never be mistaken for the shell branch's own path.
  profileEdit('/account/edit'),
  notificationPreferences('/account/notifications'),

  // Business onboarding. Deliberately outside `/business/*`: that prefix is
  // gated on business access, which the user asking for this page lacks.
  createBusiness('/create-business');

  const Routes(this.path);

  final String path;
}
