import 'package:equatable/equatable.dart';

/// A user's membership in a business (api-contract §39 `businessMemberships[]`).
/// Carries the businessId + granted permissions the business shell needs to
/// resolve an outlet queue and gate staff actions. Owners hold every permission
/// but no `outletIds` (they have no staff profile); staff carry their assigned
/// outlets. See [can] and `User.primaryMembership`.
class BusinessMembership extends Equatable {
  const BusinessMembership({
    required this.businessId,
    required this.businessName,
    required this.role,
    this.permissions = const [],
    this.outletIds = const [],
  });

  final String businessId;
  final String businessName;
  final String role;
  final List<String> permissions;
  final List<String> outletIds;

  /// True when this membership grants [permission] (e.g. `queue.manage`).
  bool can(String permission) => permissions.contains(permission);

  @override
  List<Object?> get props => [
    businessId,
    businessName,
    role,
    permissions,
    outletIds,
  ];
}
