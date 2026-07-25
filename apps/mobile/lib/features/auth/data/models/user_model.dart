import 'package:antrein/features/auth/domain/entities/business_membership.dart';
import 'package:antrein/features/auth/domain/entities/user.dart';
import 'package:antrein/features/auth/domain/entities/user_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Wire model for the API user object (login/register `data.user` and `/me`).
/// Field names already match the camelCase contract, so no `@JsonKey` renames.
/// Extra `/me` fields (notificationPreferences, timestamps) are ignored until
/// the features that need them land.
@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String name,
    required String email,
    String? phoneNumber,
    String? avatarUrl,
    @Default('active') String status,
    @Default(<String>[]) List<String> roles,
    @Default(<BusinessMembershipModel>[])
    List<BusinessMembershipModel> businessMemberships,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  User toEntity() => User(
    id: id,
    name: name,
    email: email,
    roles: roles
        .map(UserRole.fromWire)
        .whereType<UserRole>()
        .toList(growable: false),
    phoneNumber: phoneNumber,
    avatarUrl: avatarUrl,
    status: status,
    businessMemberships: businessMemberships
        .map((m) => m.toEntity())
        .toList(growable: false),
  );
}

/// A `businessMemberships[]` element (api-contract §39). Carries the granted
/// permissions + assigned outlets the business shell needs.
@freezed
abstract class BusinessMembershipModel with _$BusinessMembershipModel {
  const BusinessMembershipModel._();

  const factory BusinessMembershipModel({
    required String businessId,
    required String businessName,
    required String role,
    @Default(<String>[]) List<String> permissions,
    @Default(<String>[]) List<String> outletIds,
  }) = _BusinessMembershipModel;

  factory BusinessMembershipModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessMembershipModelFromJson(json);

  BusinessMembership toEntity() => BusinessMembership(
    businessId: businessId,
    businessName: businessName,
    role: role,
    permissions: permissions,
    outletIds: outletIds,
  );
}
