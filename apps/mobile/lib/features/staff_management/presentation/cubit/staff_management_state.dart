part of 'staff_management_cubit.dart';

enum StaffListStatus { initial, loading, success, empty, failure }

@freezed
abstract class StaffManagementState with _$StaffManagementState {
  const factory StaffManagementState({
    @Default(StaffListStatus.initial) StaffListStatus status,
    @Default(<ManagedStaff>[]) List<ManagedStaff> staff,
    @Default(<ServiceOption>[]) List<ServiceOption> services,
    @Default(false) bool isRefreshing,
    @Default(false) bool isSaving,

    /// The member a deactivate is running for — locks the row's actions.
    String? actingStaffId,

    /// Set after a successful §50 invite so the owner can share the id when the
    /// invitation email does not arrive.
    String? invitationId,
    String? invitedEmail,
    String? message,
  }) = _StaffManagementState;
}
