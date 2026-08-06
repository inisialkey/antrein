part of 'notifications_cubit.dart';

enum NotificationsStatus { initial, loading, success, empty, failure }

@freezed
abstract class NotificationsState with _$NotificationsState {
  const NotificationsState._();

  const factory NotificationsState({
    @Default(NotificationsStatus.initial) NotificationsStatus status,
    @Default(<AppNotification>[]) List<AppNotification> items,
    @Default(false) bool unreadOnly,
    @Default(0) int unreadCount,
    @Default(false) bool unreadCapped,
    @Default(false) bool isRefreshing,
    @Default(false) bool isLoadingMore,
    String? nextCursor,
    String? message,
  }) = _NotificationsState;

  bool get hasMore => nextCursor != null;

  /// Badge label. Saturates rather than showing a number the count can't back —
  /// see `NotificationsCubit.unreadBadgeCap`.
  String get unreadLabel => unreadCapped ? '$unreadCount+' : '$unreadCount';
}
