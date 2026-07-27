/// The product roles a user may hold. The backend derives these (never the
/// client); a user may hold more than one. Owner vs staff differ only by
/// permissions and share the business shell
/// (flutter-brief §3, app-architecture §25).
enum UserRole {
  customer('customer'),
  businessOwner('business_owner'),
  staff('staff');

  const UserRole(this.wire);

  /// The value as it appears in the API `roles` array.
  final String wire;

  static UserRole? fromWire(String value) {
    for (final role in UserRole.values) {
      if (role.wire == value) return role;
    }
    return null;
  }
}
