import 'dart:async';

import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/core/realtime/realtime_client.dart';
import 'package:antrein/core/realtime/realtime_event.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/usecases/get_customer_queue.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'customer_queue_state.dart';
part 'customer_queue_cubit.freezed.dart';

/// Live view of the customer's own queue position (contract §81). The
/// `/realtime` feed (§107) drives updates; a slow poll + pull-to-refresh recover
/// anything dropped between reconnects (§113).
@injectable
class CustomerQueueCubit extends Cubit<CustomerQueueState> {
  CustomerQueueCubit(this._getQueue, this._realtime)
    : super(const CustomerQueueState(status: QueueLoadStatus.initial));

  final GetCustomerQueue _getQueue;
  final RealtimeClient _realtime;
  Timer? _pollTimer;
  StreamSubscription<RealtimeEvent>? _eventSub;
  StreamSubscription<void>? _connSub;
  String? _bookingId;

  Future<void> load(String bookingId) async {
    _bookingId = bookingId;
    emit(state.copyWith(status: QueueLoadStatus.loading));
    await _fetch(silent: false);
    _startPolling();
    _startRealtime();
  }

  /// Foreground refresh (pull-to-refresh) — keeps the current screen visible.
  Future<void> refresh() => _fetch(silent: true);

  Future<void> _fetch({required bool silent}) async {
    final bookingId = _bookingId;
    if (bookingId == null) return;
    if (silent) emit(state.copyWith(isRefreshing: true));
    final result = await _getQueue(
      GetCustomerQueueParams(bookingId: bookingId),
    );
    result.match(
      (failure) {
        if (failure.code == ApiErrorCodes.queueEntryNotFound) {
          _pollTimer?.cancel();
          emit(
            state.copyWith(
              status: QueueLoadStatus.empty,
              isRefreshing: false,
              message: null,
            ),
          );
        } else if (silent) {
          // Background poll failure: keep the last-known position on screen.
          emit(state.copyWith(isRefreshing: false));
        } else {
          emit(
            state.copyWith(
              status: QueueLoadStatus.failure,
              isRefreshing: false,
              message: failure.message,
            ),
          );
        }
      },
      (entry) {
        if (entry.isTerminal) _pollTimer?.cancel();
        emit(
          state.copyWith(
            status: QueueLoadStatus.success,
            entry: entry,
            isRefreshing: false,
            message: null,
          ),
        );
      },
    );
  }

  /// Live queue updates over WebSocket (§107). The customer's own events arrive
  /// on the auto-joined `user:{id}` room; each — and every (re)connect (§112) —
  /// triggers an authoritative REST refetch rather than trusting the payload.
  void _startRealtime() {
    unawaited(_eventSub?.cancel());
    unawaited(_connSub?.cancel());
    _eventSub = _realtime.events
        .where(
          (e) =>
              e.type == 'queue.entry.updated.v1' &&
              e.data['bookingId'] == _bookingId,
        )
        .listen((_) => unawaited(refresh()));
    _connSub = _realtime.connections.listen((_) => unawaited(refresh()));
    if (!_realtime.isConnected) unawaited(_realtime.connect());
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // ponytail: slow safety poll behind the WebSocket feed — recovers an event
    // dropped between reconnects (§113 at-least-once). WS is the primary path.
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (state.entry?.isTerminal ?? false) {
        _pollTimer?.cancel();
        return;
      }
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
