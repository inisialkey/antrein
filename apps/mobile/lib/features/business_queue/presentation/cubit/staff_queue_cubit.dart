import 'dart:async';

import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/core/realtime/realtime_client.dart';
import 'package:antrein/core/realtime/realtime_event.dart';
import 'package:antrein/core/utils/idempotency.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board_entry.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_command.dart';
import 'package:antrein/features/business_queue/domain/repositories/business_queue_repository.dart';
import 'package:antrein/features/discovery/domain/entities/service_item.dart';
import 'package:antrein/features/discovery/domain/entities/staff_member.dart';
import 'package:antrein/features/discovery/domain/repositories/discovery_repository.dart';
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
  StaffQueueCubit(this._repo, this._realtime, this._discovery)
    : super(const StaffQueueState(status: BoardStatus.initial));

  final BusinessQueueRepository _repo;
  final RealtimeClient _realtime;
  final DiscoveryRepository _discovery;
  Timer? _pollTimer;
  StreamSubscription<RealtimeEvent>? _eventSub;
  StreamSubscription<void>? _connSub;
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
        _startRealtime();
      },
    );
  }

  /// Foreground refresh (pull-to-refresh / manual) — keeps the board visible.
  Future<void> refresh() => _fetch(silent: true);

  Future<void> _fetch({required bool silent}) async {
    final businessId = _businessId;
    final outletId = _outletId;
    if (businessId == null || outletId == null) return;
    // A locally-moved waiting list awaits its reason — don't clobber the preview.
    if (silent && (state.hasPendingReorder || state.isReordering)) return;
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
      idempotencyKey: newIdempotencyKey(),
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

  /// Loads (once) the service catalog backing the walk-in form (§67).
  Future<void> loadWalkInServices() async {
    final businessId = _businessId;
    if (businessId == null ||
        state.walkInServices != null ||
        state.isLoadingServices) {
      return;
    }
    emit(state.copyWith(isLoadingServices: true));
    final result = await _discovery.listServices(businessId);
    result.match(
      (failure) => emit(
        state.copyWith(isLoadingServices: false, actionError: failure.message),
      ),
      (services) => emit(
        state.copyWith(isLoadingServices: false, walkInServices: services),
      ),
    );
  }

  /// Loads (once) the barbers offered by the start-service picker (§87). A
  /// walk-in entry carries no staffId, and `start-service` rejects a missing one
  /// with `STAFF_NOT_AVAILABLE`, so the barber is chosen at this point.
  Future<void> loadStaffOptions() async {
    final businessId = _businessId;
    if (businessId == null ||
        state.staffOptions != null ||
        state.isLoadingStaff) {
      return;
    }
    emit(state.copyWith(isLoadingStaff: true));
    final result = await _discovery.listStaff(businessId);
    result.match(
      (failure) => emit(
        state.copyWith(isLoadingStaff: false, actionError: failure.message),
      ),
      (staff) => emit(
        state.copyWith(
          isLoadingStaff: false,
          staffOptions: staff.where((s) => s.isActive).toList(),
        ),
      ),
    );
  }

  /// Creates a walk-in booking + queue entry (§67). Success surfaces the
  /// assigned display number and resyncs the board.
  Future<void> createWalkIn({
    required String customerName,
    required String serviceId,
    String? phoneNumber,
  }) async {
    final businessId = _businessId;
    final outletId = _outletId;
    if (businessId == null || outletId == null || state.isCreatingWalkIn) {
      return;
    }
    emit(
      state.copyWith(
        isCreatingWalkIn: true,
        walkInCreatedNumber: null,
        actionError: null,
        actionConflict: false,
      ),
    );
    final result = await _repo.createWalkIn(
      businessId: businessId,
      outletId: outletId,
      serviceId: serviceId,
      customerName: customerName,
      phoneNumber: phoneNumber,
      idempotencyKey: newIdempotencyKey(),
    );
    await result.match(
      (failure) async => emit(
        state.copyWith(isCreatingWalkIn: false, actionError: failure.message),
      ),
      (displayNumber) async {
        emit(
          state.copyWith(
            isCreatingWalkIn: false,
            walkInCreatedNumber: displayNumber,
          ),
        );
        await _fetch(silent: true);
      },
    );
  }

  /// Locally previews a waiting-list move (§90). [oldIndex]/[newIndex] use
  /// remove-then-insert semantics (`onReorderItem` reports them that way).
  /// Background refreshes pause until [commitReorder] or [cancelReorder].
  void moveWaiting(int oldIndex, int newIndex) {
    final board = state.board;
    if (board == null || state.isReordering) return;
    final moved = [...board.waiting];
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= moved.length ||
        newIndex >= moved.length) {
      return;
    }
    moved.insert(newIndex, moved.removeAt(oldIndex));
    emit(
      state.copyWith(
        board: _withWaiting(board, moved),
        hasPendingReorder: true,
      ),
    );
  }

  /// Commits the previewed order with the required [reason] (§90). The payload
  /// is exactly the waiting+skipped id set, guarded by the aggregate version.
  Future<void> commitReorder(String reason) async {
    final businessId = _businessId;
    final outletId = _outletId;
    final board = state.board;
    if (businessId == null ||
        outletId == null ||
        board == null ||
        !state.hasPendingReorder ||
        state.isReordering) {
      return;
    }
    emit(state.copyWith(isReordering: true, actionError: null));
    final result = await _repo.reorderQueue(
      businessId: businessId,
      outletId: outletId,
      businessDate: board.businessDate,
      expectedQueueVersion: board.version,
      orderedQueueEntryIds: [
        for (final e in board.waiting) e.queueEntryId,
        for (final e in board.skipped) e.queueEntryId,
      ],
      reason: reason,
      idempotencyKey: newIdempotencyKey(),
    );
    result.match(
      (failure) => emit(
        state.copyWith(
          isReordering: false,
          hasPendingReorder: false,
          actionError: failure.message,
          actionConflict: failure.code == ApiErrorCodes.queueVersionConflict,
        ),
      ),
      (_) => emit(
        state.copyWith(isReordering: false, hasPendingReorder: false),
      ),
    );
    // Success or failure, REST is authoritative — resync the real order.
    await _fetch(silent: true);
  }

  /// Discards the previewed order and restores the server board.
  Future<void> cancelReorder() async {
    if (!state.hasPendingReorder) return;
    emit(state.copyWith(hasPendingReorder: false));
    await _fetch(silent: true);
  }

  static QueueBoard _withWaiting(
    QueueBoard board,
    List<QueueBoardEntry> waiting,
  ) => QueueBoard(
    businessDate: board.businessDate,
    outletId: board.outletId,
    isOpen: board.isOpen,
    version: board.version,
    waiting: waiting,
    skipped: board.skipped,
    currentServing: board.currentServing,
    updatedAt: board.updatedAt,
  );

  /// Live board updates over WebSocket (§108). A `queue.snapshot.updated.v1`
  /// event is a hint: it triggers an authoritative REST refetch. Rooms are lost
  /// on disconnect, so every (re)connect re-joins the outlet room and resyncs.
  void _startRealtime() {
    unawaited(_eventSub?.cancel());
    unawaited(_connSub?.cancel());
    _eventSub = _realtime.events
        .where(
          (e) =>
              e.type == 'queue.snapshot.updated.v1' &&
              e.data['outletId'] == _outletId,
        )
        .listen((_) {
          if (state.actingEntryId == null) unawaited(refresh());
        });
    _connSub = _realtime.connections.listen((_) {
      _subscribe();
      unawaited(refresh());
    });
    if (_realtime.isConnected) {
      _subscribe();
    } else {
      unawaited(_realtime.connect());
    }
  }

  void _subscribe() {
    final outletId = _outletId;
    final businessDate = state.board?.businessDate;
    if (outletId != null && businessDate != null) {
      _realtime.subscribeOutletQueue(outletId, businessDate);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // ponytail: slow safety poll behind the WebSocket feed — recovers a snapshot
    // event dropped between reconnects (§113). WS is the primary refresh path.
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      // don't fight an in-flight command mid-apply
      if (state.actingEntryId != null) return;
      unawaited(refresh());
    });
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    unawaited(_eventSub?.cancel());
    unawaited(_connSub?.cancel());
    return super.close();
  }
}
