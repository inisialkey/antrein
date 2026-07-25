import 'dart:async';

import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/usecases/get_customer_queue.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'customer_queue_state.dart';
part 'customer_queue_cubit.freezed.dart';

/// Live view of the customer's own queue position (contract §81). Until the M9
/// WebSocket feed lands, freshness comes from a short poll + pull-to-refresh.
@injectable
class CustomerQueueCubit extends Cubit<CustomerQueueState> {
  CustomerQueueCubit(this._getQueue)
    : super(const CustomerQueueState(status: QueueLoadStatus.initial));

  final GetCustomerQueue _getQueue;
  Timer? _pollTimer;
  String? _bookingId;

  Future<void> load(String bookingId) async {
    _bookingId = bookingId;
    emit(state.copyWith(status: QueueLoadStatus.loading));
    await _fetch(silent: false);
    _startPolling();
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

  void _startPolling() {
    _pollTimer?.cancel();
    // ponytail: 15s poll stands in for the M9 realtime queue feed; upgrade to the
    // WebSocket `/realtime` subscription when it lands.
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
    return super.close();
  }
}
