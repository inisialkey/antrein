import 'dart:async';

import 'package:antrein/features/booking/domain/entities/booking_draft.dart';
import 'package:antrein/features/booking/domain/entities/slot.dart';
import 'package:antrein/features/booking/domain/usecases/get_availability.dart';
import 'package:antrein/features/discovery/domain/entities/staff_member.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'slot_picker_cubit.freezed.dart';
part 'slot_picker_state.dart';

/// Slot selection for one draft: pick a staff member and a date, load slots
/// (staffId is required by the availability API — ADR 0019).
@injectable
class SlotPickerCubit extends Cubit<SlotPickerState> {
  SlotPickerCubit(this._getAvailability)
    : super(const SlotPickerState(status: SlotLoadStatus.initial));

  final GetAvailability _getAvailability;

  late BookingDraft _draft;
  late List<StaffMember> _eligibleStaff;

  BookingDraft get draft => _draft;

  void init(BookingDraft draft, List<StaffMember> staff) {
    _draft = draft;
    _eligibleStaff = staff
        .where((s) => s.isActive && s.canPerform(draft.service.id))
        .toList(growable: false);
    final first = _eligibleStaff.isEmpty ? null : _eligibleStaff.first;
    emit(
      state.copyWith(
        staff: _eligibleStaff,
        selectedStaff: first,
        selectedDate: _today(),
      ),
    );
    if (first != null) {
      unawaited(_load());
    }
  }

  void selectStaff(StaffMember staff) {
    emit(state.copyWith(selectedStaff: staff, selectedSlot: null));
    unawaited(_load());
  }

  void selectDate(DateTime date) {
    emit(state.copyWith(selectedDate: date, selectedSlot: null));
    unawaited(_load());
  }

  void selectSlot(Slot slot) {
    if (!slot.available) return;
    emit(state.copyWith(selectedSlot: slot));
  }

  /// Draft enriched with the current staff + slot selection.
  BookingDraft buildDraft() => _draft.copyWith(
    staff: state.selectedStaff,
    slot: state.selectedSlot,
  );

  Future<void> _load() async {
    final staff = state.selectedStaff;
    final date = state.selectedDate;
    if (staff == null || date == null) return;
    emit(state.copyWith(status: SlotLoadStatus.loading, slots: const []));
    final result = await _getAvailability(
      GetAvailabilityParams(
        businessId: _draft.businessId,
        outletId: _draft.outlet.id,
        serviceId: _draft.service.id,
        staffId: staff.id,
        date: _dateString(date),
      ),
    );
    result.match(
      (failure) => emit(
        state.copyWith(
          status: SlotLoadStatus.failure,
          message: failure.message,
        ),
      ),
      (slots) => emit(
        state.copyWith(
          status: slots.any((s) => s.available)
              ? SlotLoadStatus.success
              : SlotLoadStatus.empty,
          slots: slots,
        ),
      ),
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
