import 'dart:async';

import 'package:antrein/core/realtime/realtime_client.dart';
import 'package:antrein/core/realtime/realtime_event.dart';
import 'package:antrein/features/notifications/domain/entities/app_notification.dart';
import 'package:antrein/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'notifications_state.dart';
part 'notifications_cubit.freezed.dart';

/// The in-app notification inbox (api-contract §92–§95). Lives for as long as
/// the customer shell does, because the tab badge needs the unread count while
/// the user is on any other tab.
///
/// ponytail: the cubit calls the repository directly — three one-line use-case
/// wrappers would be pure boilerplate, same as `BusinessBookingsCubit`.
@injectable
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._repo, this._realtime)
    : super(const NotificationsState());

  /// The badge is counted from a single unread page rather than by paging the
  /// whole inbox, so it saturates here and the UI renders `20+`.
  static const int unreadBadgeCap = 20;

  /// The outbox dispatcher publishes the WebSocket event *before* it writes the
  /// notification row (ADR 0044), so an immediate refetch would miss the very
  /// row the event announces. Waiting a beat is cheaper than an event id and a
  /// retry loop; a miss still recovers on pull-to-refresh or the next tab open.
  static const Duration pushSettleDelay = Duration(seconds: 2);

  static const int _pageLimit = 20;
  static const String _queueEvent = 'queue.entry.updated.v1';

  final NotificationsRepository _repo;
  final RealtimeClient _realtime;
  StreamSubscription<RealtimeEvent>? _eventSub;
  StreamSubscription<void>? _connSub;
  Timer? _settleTimer;

  Future<void> load() async {
    emit(state.copyWith(status: NotificationsStatus.loading, message: null));
    await _fetchFirstPage(silent: false);
    _startRealtime();
  }

  /// Foreground refresh (pull-to-refresh, tab re-entry) — keeps the list up.
  Future<void> refresh() => _fetchFirstPage(silent: true);

  Future<void> setUnreadOnly({required bool unreadOnly}) async {
    if (unreadOnly == state.unreadOnly) return;
    emit(
      state.copyWith(
        unreadOnly: unreadOnly,
        status: NotificationsStatus.loading,
        items: const [],
        nextCursor: null,
      ),
    );
    await _fetchFirstPage(silent: false);
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _repo.list(
      isRead: _filter,
      cursor: cursor,
      limit: _pageLimit,
    );
    result.match(
      (failure) =>
          emit(state.copyWith(isLoadingMore: false, message: failure.message)),
      (page) => emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          nextCursor: page.nextCursor,
          isLoadingMore: false,
        ),
      ),
    );
  }

  /// §94. Read state is authoritative on the server, so the list is re-read
  /// rather than patched — the unread filter drops the row for free that way.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final result = await _repo.markRead(notification.id);
    await result.match(
      (failure) async => emit(state.copyWith(message: failure.message)),
      (_) => _fetchFirstPage(silent: true),
    );
  }

  /// §95.
  Future<void> markAllRead() async {
    final result = await _repo.markAllRead();
    await result.match(
      (failure) async => emit(state.copyWith(message: failure.message)),
      (_) => _fetchFirstPage(silent: true),
    );
  }

  bool? get _filter => state.unreadOnly ? false : null;

  Future<void> _fetchFirstPage({required bool silent}) async {
    if (silent) emit(state.copyWith(isRefreshing: true));

    final result = await _repo.list(isRead: _filter, limit: _pageLimit);
    // Shell-scoped, so a logout can close this cubit mid-request.
    if (isClosed) return;
    await result.match(
      (failure) async => emit(
        silent
            // A background refresh failure keeps the last-known inbox on screen.
            ? state.copyWith(isRefreshing: false)
            : state.copyWith(
                status: NotificationsStatus.failure,
                isRefreshing: false,
                message: failure.message,
              ),
      ),
      (page) async {
        emit(
          state.copyWith(
            status: page.items.isEmpty
                ? NotificationsStatus.empty
                : NotificationsStatus.success,
            items: page.items,
            nextCursor: page.nextCursor,
            isRefreshing: false,
            message: null,
          ),
        );
        await _refreshUnreadCount();
      },
    );
  }

  /// ponytail: one dedicated call keeps the badge's definition in one place —
  /// it repeats the page request while the unread filter is on, which is one
  /// small query. Swap for a count endpoint if the backend ever grows one.
  Future<void> _refreshUnreadCount() async {
    final result = await _repo.list(isRead: false, limit: unreadBadgeCap);
    if (isClosed) return;
    result.match(
      // The badge is decoration; a failed count must not disturb the list.
      (_) {},
      (page) => emit(
        state.copyWith(
          unreadCount: page.items.length,
          unreadCapped: page.nextCursor != null,
        ),
      ),
    );
  }

  /// A queue event on the auto-joined `user:{id}` room (§107) is the only thing
  /// that mints a notification today, so it doubles as the inbox's live feed.
  void _startRealtime() {
    unawaited(_eventSub?.cancel());
    unawaited(_connSub?.cancel());
    _eventSub = _realtime.events.where((e) => e.type == _queueEvent).listen((
      _,
    ) {
      _settleTimer?.cancel();
      _settleTimer = Timer(pushSettleDelay, () {
        if (!isClosed) unawaited(refresh());
      });
    });
    _connSub = _realtime.connections.listen((_) {
      if (!isClosed) unawaited(refresh());
    });
    if (!_realtime.isConnected) unawaited(_realtime.connect());
  }

  @override
  Future<void> close() {
    _settleTimer?.cancel();
    unawaited(_eventSub?.cancel());
    unawaited(_connSub?.cancel());
    return super.close();
  }
}
