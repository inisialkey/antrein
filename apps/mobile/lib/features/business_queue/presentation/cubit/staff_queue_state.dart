part of 'staff_queue_cubit.dart';

enum BoardStatus { initial, loading, success, failure }

@freezed
sealed class StaffQueueState with _$StaffQueueState {
  const factory StaffQueueState({
    required BoardStatus status,
    QueueBoard? board,
    @Default(false) bool isRefreshing,

    /// The entry a command is currently in flight for (drives per-row spinners
    /// and blocks concurrent commands); null when idle.
    String? actingEntryId,

    /// Last command error message, surfaced as a transient banner/snackbar.
    String? actionError,

    /// True when the last command lost a version race and the board was resynced.
    @Default(false) bool actionConflict,

    /// Load-failure message for the whole board.
    String? message,

    /// Service catalog for the walk-in form; null until first loaded (§67).
    List<ServiceItem>? walkInServices,
    @Default(false) bool isLoadingServices,
    @Default(false) bool isCreatingWalkIn,

    /// Display number of the last created walk-in — transient snackbar signal.
    String? walkInCreatedNumber,

    /// The waiting list was moved locally and awaits a reorder reason (§90).
    /// Background refreshes are suppressed so they can't clobber the preview.
    @Default(false) bool hasPendingReorder,
    @Default(false) bool isReordering,
  }) = _StaffQueueState;
}
