part of 'slot_picker_cubit.dart';

enum SlotLoadStatus { initial, loading, success, empty, failure }

/// Single-state shape (not a union): staff/date selections must survive slot
/// reloads, per the state conventions in frontend/state-management.
@freezed
sealed class SlotPickerState with _$SlotPickerState {
  const factory SlotPickerState({
    required SlotLoadStatus status,
    @Default(<StaffMember>[]) List<StaffMember> staff,
    StaffMember? selectedStaff,
    DateTime? selectedDate,
    @Default(<Slot>[]) List<Slot> slots,
    Slot? selectedSlot,
    String? message,
  }) = _SlotPickerState;
}
