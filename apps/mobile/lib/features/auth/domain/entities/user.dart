import 'package:antrein/features/auth/domain/entities/user_role.dart';
import 'package:equatable/equatable.dart';

/// The signed-in user. Domain entity — optimised for app behaviour, not the
/// database or wire shape. `roles` decides which navigation shell the user
/// enters (see [hasBusinessAccess]).
class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    this.phoneNumber,
    this.avatarUrl,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String email;
  final List<UserRole> roles;
  final String? phoneNumber;
  final String? avatarUrl;
  final String status;

  /// True when the account holds a business-side role (owner or staff) and may
  /// enter the business shell. Customer-only accounts use the customer shell.
  /// Roles are customer-only until the memberships module (M4).
  bool get hasBusinessAccess =>
      roles.contains(UserRole.businessOwner) || roles.contains(UserRole.staff);

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    roles,
    phoneNumber,
    avatarUrl,
    status,
  ];
}
