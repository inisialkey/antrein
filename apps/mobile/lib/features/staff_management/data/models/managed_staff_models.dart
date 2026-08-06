import 'package:antrein/features/staff_management/domain/entities/managed_staff.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'managed_staff_models.freezed.dart';
part 'managed_staff_models.g.dart';

/// Wire models for staff management (api-contract §41, §50, §52, §53).

@freezed
abstract class ManagedStaffModel with _$ManagedStaffModel {
  const ManagedStaffModel._();

  const factory ManagedStaffModel({
    required String id,
    required String name,
    @Default('barber') String role,
    @Default(true) bool isActive,
    @Default(<String>[]) List<String> eligibleServiceIds,
  }) = _ManagedStaffModel;

  factory ManagedStaffModel.fromJson(Map<String, dynamic> json) =>
      _$ManagedStaffModelFromJson(json);

  ManagedStaff toEntity() => ManagedStaff(
    id: id,
    name: name,
    role: role,
    isActive: isActive,
    eligibleServiceIds: eligibleServiceIds,
  );
}

/// §50 response — the member only joins the list once they accept (§51).
@freezed
abstract class StaffInvitationModel with _$StaffInvitationModel {
  const factory StaffInvitationModel({
    required String invitationId,
    required String email,
  }) = _StaffInvitationModel;

  factory StaffInvitationModel.fromJson(Map<String, dynamic> json) =>
      _$StaffInvitationModelFromJson(json);
}
