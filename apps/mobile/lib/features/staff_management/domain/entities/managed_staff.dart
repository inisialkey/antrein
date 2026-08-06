import 'package:equatable/equatable.dart';

/// Roles a staff member can be invited as (api-contract §128 — `owner` only
/// ever comes from creating the business).
enum StaffRole { manager, barber, frontDesk, cashier }

/// Wire label ↔ enum. Unknown labels keep the raw string so a server-side
/// addition renders rather than crashes.
extension StaffRoleX on StaffRole {
  String get wire => switch (this) {
    StaffRole.manager => 'manager',
    StaffRole.barber => 'barber',
    StaffRole.frontDesk => 'front_desk',
    StaffRole.cashier => 'cashier',
  };

  static StaffRole? fromWire(String? value) => switch (value) {
    'manager' => StaffRole.manager,
    'barber' => StaffRole.barber,
    'front_desk' => StaffRole.frontDesk,
    'cashier' => StaffRole.cashier,
    _ => null,
  };
}

/// A staff member as the owner manages them (api-contract §41, §52, §53).
class ManagedStaff extends Equatable {
  const ManagedStaff({
    required this.id,
    required this.name,
    required this.role,
    this.isActive = true,
    this.eligibleServiceIds = const [],
  });

  final String id;
  final String name;

  /// Raw role label — [roleEnum] is null for a role this build doesn't know.
  final String role;
  final bool isActive;

  /// Empty = eligible for every service (backend rule).
  final List<String> eligibleServiceIds;

  StaffRole? get roleEnum => StaffRoleX.fromWire(role);

  @override
  List<Object?> get props => [id, name, role, isActive, eligibleServiceIds];
}

/// Minimal service row for the eligibility picker (api-contract §40).
class ServiceOption extends Equatable {
  const ServiceOption({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// What the staff form submits. A null [id] invites by email (§50), otherwise
/// it updates the existing profile (§52).
class StaffDraft extends Equatable {
  const StaffDraft({
    required this.displayName,
    required this.role,
    this.id,
    this.email,
    this.outletIds = const [],
    this.eligibleServiceIds = const [],
    this.isActive = true,
  });

  final String? id;

  /// Only read when inviting; §52 cannot change the account behind a profile.
  final String? email;
  final String displayName;
  final StaffRole role;
  final List<String> outletIds;
  final List<String> eligibleServiceIds;
  final bool isActive;

  bool get isInvite => id == null;

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    role,
    outletIds,
    eligibleServiceIds,
    isActive,
  ];
}
