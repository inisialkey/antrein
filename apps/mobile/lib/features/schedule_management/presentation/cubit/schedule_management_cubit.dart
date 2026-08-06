import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/utils/idempotency.dart';
import 'package:antrein/features/schedule_management/domain/entities/weekly_schedule.dart';
import 'package:antrein/features/schedule_management/domain/repositories/schedule_management_repository.dart';
import 'package:antrein/features/staff_management/staff_management.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'schedule_management_state.dart';
part 'schedule_management_cubit.freezed.dart';

/// Outlet hours, closed dates and staff schedules (api-contract §54–§58.1,
/// ui-feature-spec §37). Both schedule endpoints are full-week replaces, so the
/// cubit keeps an editable copy of the whole week and PUTs it in one go.
@injectable
class ScheduleManagementCubit extends Cubit<ScheduleManagementState> {
  ScheduleManagementCubit(this._repo, this._staff)
    : super(const ScheduleManagementState());

  final ScheduleManagementRepository _repo;
  final StaffManagementRepository _staff;

  late String _businessId;
  late String _outletId;
  String? _closedDateKey;

  Future<void> load(String businessId, String outletId) async {
    _businessId = businessId;
    _outletId = outletId;
    emit(state.copyWith(status: ScheduleStatus.loading, message: null));

    final hoursResult = await _repo.getOperatingHours(businessId, outletId);
    if (isClosed) return;
    final hours = hoursResult.match<OperatingHours?>((_) => null, (v) => v);
    if (hours == null) {
      emit(
        state.copyWith(
          status: ScheduleStatus.failure,
          message: hoursResult.match((f) => f.message, (_) => null),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ScheduleStatus.success,
        timezone: hours.timezone,
        days: hours.days,
      ),
    );
    await refreshClosedDates();
    await _loadStaff();
  }

  /// Only upcoming closures matter to the owner; past ones stay in history.
  Future<void> refreshClosedDates() async {
    final result = await _repo.listClosedDates(
      _businessId,
      _outletId,
      dateFrom: _today(),
    );
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(message: failure.message)),
      (items) => emit(state.copyWith(closedDates: items)),
    );
  }

  void setOperatingDay(int index, OperatingDay day) {
    final days = [...state.days];
    days[index] = day;
    emit(state.copyWith(days: days));
  }

  /// §55.
  Future<void> saveOperatingHours() async {
    if (state.isSavingHours) return;
    emit(state.copyWith(isSavingHours: true, message: null));

    final result = await _repo.replaceOperatingHours(
      _businessId,
      _outletId,
      OperatingHours(timezone: state.timezone, days: state.days),
    );
    if (isClosed) return;
    final failure = result.match<Failure?>((f) => f, (_) => null);
    emit(
      state.copyWith(
        isSavingHours: false,
        message: failure?.message,
        savedTick: failure == null ? state.savedTick + 1 : state.savedTick,
      ),
    );
  }

  /// §57. Returns null on success, otherwise the message for the form.
  Future<String?> addClosedDate(String date, String? reason) async {
    if (state.isSavingClosedDate) return null;
    emit(state.copyWith(isSavingClosedDate: true, message: null));

    final result = await _repo.createClosedDate(
      _businessId,
      _outletId,
      date: date,
      reason: reason,
      idempotencyKey: _closedDateKey ??= newIdempotencyKey(),
    );
    if (isClosed) return null;
    emit(state.copyWith(isSavingClosedDate: false));

    final failure = result.match<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      // A coded rejection is stored against the key; replaying it replays it.
      if (failure.code != null) _closedDateKey = null;
      return failure.message;
    }
    _closedDateKey = null;
    await refreshClosedDates();
    return null;
  }

  /// §58 — loads the selected member's week into the editor.
  Future<void> selectStaff(String staffId) async {
    emit(
      state.copyWith(
        selectedStaffId: staffId,
        isLoadingStaffSchedule: true,
        staffDays: const [],
        message: null,
      ),
    );

    final result = await _repo.getStaffSchedule(_businessId, staffId);
    if (isClosed) return;
    result.match(
      (failure) => emit(
        state.copyWith(
          isLoadingStaffSchedule: false,
          message: failure.message,
        ),
      ),
      (schedule) => emit(
        state.copyWith(
          isLoadingStaffSchedule: false,
          staffDays: schedule.days,
        ),
      ),
    );
  }

  void setStaffDay(int index, StaffDay day) {
    final days = [...state.staffDays];
    days[index] = day;
    emit(state.copyWith(staffDays: days));
  }

  /// §58.1.
  Future<void> saveStaffSchedule() async {
    final staffId = state.selectedStaffId;
    if (staffId == null || state.isSavingStaff) return;
    emit(state.copyWith(isSavingStaff: true, message: null));

    final result = await _repo.replaceStaffSchedule(
      _businessId,
      StaffSchedule(
        staffId: staffId,
        timezone: state.timezone,
        days: state.staffDays,
      ),
    );
    if (isClosed) return;
    final failure = result.match<Failure?>((f) => f, (_) => null);
    emit(
      state.copyWith(
        isSavingStaff: false,
        message: failure?.message,
        savedTick: failure == null ? state.savedTick + 1 : state.savedTick,
      ),
    );
  }

  Future<void> _loadStaff() async {
    final result = await _staff.listStaff(_businessId);
    if (isClosed) return;
    // The roster only feeds the staff-schedule tab; a failure there must not
    // take the operating hours down with it.
    result.match(
      (_) {},
      (items) => emit(
        state.copyWith(staff: items.where((s) => s.isActive).toList()),
      ),
    );
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
