part of 'schedule_management_cubit.dart';

enum ScheduleStatus { initial, loading, success, failure }

@freezed
abstract class ScheduleManagementState with _$ScheduleManagementState {
  const factory ScheduleManagementState({
    @Default(ScheduleStatus.initial) ScheduleStatus status,

    /// Outlet timezone; §55 and §58.1 reject anything else.
    @Default('Asia/Jakarta') String timezone,

    /// Editable copy of the week — always seven days, monday first.
    @Default(<OperatingDay>[]) List<OperatingDay> days,
    @Default(<ClosedDate>[]) List<ClosedDate> closedDates,
    @Default(<ManagedStaff>[]) List<ManagedStaff> staff,
    String? selectedStaffId,
    @Default(<StaffDay>[]) List<StaffDay> staffDays,
    @Default(false) bool isLoadingStaffSchedule,
    @Default(false) bool isSavingHours,
    @Default(false) bool isSavingStaff,
    @Default(false) bool isSavingClosedDate,

    /// Bumped on every successful save so the page can show a localized
    /// confirmation without the cubit knowing about l10n.
    @Default(0) int savedTick,
    String? message,
  }) = _ScheduleManagementState;
}
