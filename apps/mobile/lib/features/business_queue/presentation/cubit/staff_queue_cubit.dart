import 'dart:async';
import 'dart:math';

import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board_entry.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_command.dart';
import 'package:antrein/features/business_queue/domain/repositories/business_queue_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'staff_queue_state.dart';
part 'staff_queue_cubit.freezed.dart';

/// Drives the staff queue board (contract §82–§89): resolves the outlet, loads
/// the snapshot, polls for freshness, and applies versioned lifecycle commands.
///
/// ponytail: the cubit calls the repository directly — seven one-line use-case
/// wrappers would be pure boilerplate. Add a use case only if command logic
/// grows past a pass-through.
@injectable
class StaffQueueCubit extends Cubit<StaffQueueState> {
  StaffQueueCubit(this._repo)
    : super(const StaffQueueState(status: BoardStatus.initial));

  final BusinessQueueRepository _repo;
  Timer? _pollTimer;
  String? _businessId;
  String? _outletId;

  Future<void> load({
    required String businessId,
    required List<String> membershipOutletIds,
  }) async {
    _businessId = businessId;
    emit(state.copyWith(status: BoardStatus.loading, message: null));
    final resolved = await _repo.resolveOutletId(
      businessId: businessId,
      membershipOutletIds: membershipOutletIds,
    );
    await resolved.match(
      (failure) async => emit(
        state.copyWith(status: BoardStatus.failure, message: failure.message),
      ),
      (outletId) async {
        _outletId = outletId;
        await _fetch(silent: false);
        _startPolling();
      },
    );
  }

  /// Foreground refresh (pull-to-refresh / manual) — keeps the board visible.
  Future<void> refresh() => _fetch(silent: true);

  Future<void> _fetch({required bool silent}) async {
    final businessId = _businessId;
    final outletId = _outletId;
    if (businessId == null || outletId == null) return;
    if (silent) emit(state.copyWith(isRefreshing: true));
    final result = await _repo.getBoard(
      businessId: businessId,
      outletId: outletId,
    );
    result.match(
      (failure) {
        // A background/poll failure keeps the last-known board on screen.
        if (silent) {
          emit(state.copyWith(isRefreshing: false));
        } else {
          emit(
            state.copyWith(
              status: BoardStatus.failure,
              isRefreshing: false,
              message: failure.message,
            ),
          );
        }
      },
      (board) => emit(
        state.copyWith(
          status: BoardStatus.success,
          board: board,
          isRefreshing: false,
          message: null,
        ),
      ),
    );
  }

  /// Applies [command] to [entry] with the entry's version. The board is
  /// re-read afterwards (REST is authoritative); a `QUEUE_VERSION_CONFLICT`
  /// means the board moved under us, so we resync and flag the conflict.
  Future<void> runCommand(
    QueueBoardEntry entry,
    QueueCommand command, {
    String? reason,
    String? staffId,
  }) async {
    final businessId = _businessId;
    if (businessId == null || state.actingEntryId != null) return;
    emit(
      state.copyWith(
        actingEntryId: entry.queueEntryId,
        actionError: null,
        actionConflict: false,
      ),
    );
    final result = await _repo.runCommand(
      businessId: businessId,
      queueEntryId: entry.queueEntryId,
      command: command,
      expectedVersion: entry.version,
      idempotencyKey: _newKey(),
      reason: reason,
      staffId: staffId,
    );
    await result.match(
      (failure) async {
        final conflict = failure.code == ApiErrorCodes.queueVersionConflict;
        emit(
          state.copyWith(
            actingEntryId: null,
            actionError: failure.message,
            actionConflict: conflict,
          ),
        );
        if (conflict) await _fetch(silent: true);
      },
      (_) async {
        emit(state.copyWith(actingEntryId: null, actionError: null));
        await _fetch(silent: true);
      },
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // ponytail: 12s poll stands in for the M9 realtime queue feed; swap for the
    // WebSocket `/realtime` subscription when it lands.
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (state.actingEntryId != null)
        return; // don't fight an in-flight command
      unawaited(refresh());
    });
  }

  static String _newKey() {
    final random = Random();
    return 'idem_${DateTime.now().microsecondsSinceEpoch}_'
        '${random.nextInt(1 << 32).toRadixString(16)}';
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
