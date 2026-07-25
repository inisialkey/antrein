part of 'customer_queue_cubit.dart';

enum QueueLoadStatus { initial, loading, success, empty, failure }

@freezed
sealed class CustomerQueueState with _$CustomerQueueState {
  const factory CustomerQueueState({
    required QueueLoadStatus status,
    QueueEntry? entry,
    @Default(false) bool isRefreshing,
    String? message,
  }) = _CustomerQueueState;
}
