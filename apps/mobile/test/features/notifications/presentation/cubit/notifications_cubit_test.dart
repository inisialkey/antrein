import 'dart:async';

import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/realtime/realtime_client.dart';
import 'package:antrein/core/realtime/realtime_event.dart';
import 'package:antrein/features/notifications/domain/entities/app_notification.dart';
import 'package:antrein/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:antrein/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

class MockRealtimeClient extends Mock implements RealtimeClient {}

void main() {
  late MockNotificationsRepository repo;
  late MockRealtimeClient realtime;
  late StreamController<RealtimeEvent> events;
  late StreamController<void> connections;

  AppNotification notification({String id = 'ntf_1', bool isRead = false}) =>
      AppNotification(
        id: id,
        type: 'queue_called',
        title: 'Giliran Anda tiba',
        body: 'Nomor A012 sedang dipanggil.',
        isRead: isRead,
        createdAt: DateTime.utc(2026, 8, 6, 3),
        resourceType: 'booking',
        resourceId: 'bkg_1',
      );

  /// Answers `list` per filter so a call for the badge (isRead: false) can be
  /// distinguished from the page fetch.
  void stubList({
    NotificationPage? all,
    NotificationPage? unread,
    NotificationPage? more,
  }) {
    when(
      () => repo.list(
        isRead: any(named: 'isRead'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      if (invocation.namedArguments[#cursor] != null) {
        return Right(more ?? const NotificationPage(items: []));
      }
      if (invocation.namedArguments[#isRead] == false) {
        return Right(unread ?? const NotificationPage(items: []));
      }
      return Right(all ?? const NotificationPage(items: []));
    });
  }

  setUp(() {
    repo = MockNotificationsRepository();
    realtime = MockRealtimeClient();
    events = StreamController<RealtimeEvent>.broadcast();
    connections = StreamController<void>.broadcast();
    when(() => realtime.events).thenAnswer((_) => events.stream);
    when(() => realtime.connections).thenAnswer((_) => connections.stream);
    when(() => realtime.isConnected).thenReturn(false);
    when(() => realtime.connect()).thenAnswer((_) async {});
    stubList();
  });

  tearDown(() async {
    await events.close();
    await connections.close();
  });

  NotificationsCubit build() => NotificationsCubit(repo, realtime);

  group('load (§92)', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'lists the first page and counts the unread separately',
      build: build,
      setUp: () => stubList(
        all: NotificationPage(
          items: [
            notification(),
            notification(id: 'ntf_2', isRead: true),
          ],
        ),
        unread: NotificationPage(items: [notification()]),
      ),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.status, NotificationsStatus.success);
        expect(cubit.state.items, hasLength(2));
        expect(cubit.state.unreadCount, 1);
        expect(cubit.state.unreadCapped, isFalse);
      },
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'an inbox with nothing in it is empty, not a failure',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) => expect(cubit.state.status, NotificationsStatus.empty),
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'a failed first load surfaces the message',
      build: build,
      setUp: () => when(
        () => repo.list(
          isRead: any(named: 'isRead'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline'))),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.status, NotificationsStatus.failure);
        expect(cubit.state.message, 'offline');
      },
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'a full unread page caps the badge rather than lying about the count',
      build: build,
      setUp: () => stubList(
        all: NotificationPage(items: [notification()]),
        unread: NotificationPage(
          items: List.generate(
            NotificationsCubit.unreadBadgeCap,
            (i) => notification(id: 'ntf_$i'),
          ),
          nextCursor: 'more',
        ),
      ),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.unreadCount, NotificationsCubit.unreadBadgeCap);
        expect(cubit.state.unreadCapped, isTrue);
      },
    );
  });

  group('unread filter', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'switching to unread refetches with the filter applied',
      build: build,
      setUp: () => stubList(unread: NotificationPage(items: [notification()])),
      act: (cubit) async {
        await cubit.load();
        await cubit.setUnreadOnly(unreadOnly: true);
      },
      verify: (cubit) {
        expect(cubit.state.unreadOnly, isTrue);
        expect(cubit.state.items, hasLength(1));
        verify(
          () => repo.list(
            isRead: false,
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    blocTest<NotificationsCubit, NotificationsState>(
      're-selecting the active filter does not refetch',
      build: build,
      act: (cubit) async {
        await cubit.load();
        clearInteractions(repo);
        await cubit.setUnreadOnly(unreadOnly: false);
      },
      verify: (_) => verifyNever(
        () => repo.list(
          isRead: any(named: 'isRead'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ),
    );
  });

  group('pagination (§20)', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'load more appends the next page and clears the cursor at the end',
      build: build,
      setUp: () => stubList(
        all: NotificationPage(items: [notification()], nextCursor: 'c1'),
        more: NotificationPage(items: [notification(id: 'ntf_2')]),
      ),
      act: (cubit) async {
        await cubit.load();
        await cubit.loadMore();
      },
      verify: (cubit) {
        expect(cubit.state.items.map((n) => n.id), ['ntf_1', 'ntf_2']);
        expect(cubit.state.nextCursor, isNull);
        verify(
          () => repo.list(
            isRead: any(named: 'isRead'),
            cursor: 'c1',
            limit: any(named: 'limit'),
          ),
        ).called(1);
      },
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'load more on the last page is a no-op',
      build: build,
      setUp: () => stubList(all: NotificationPage(items: [notification()])),
      act: (cubit) async {
        await cubit.load();
        clearInteractions(repo);
        await cubit.loadMore();
      },
      verify: (_) => verifyNever(
        () => repo.list(
          isRead: any(named: 'isRead'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ),
    );
  });

  group('read state (§94, §95)', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'marking one read resyncs from REST rather than patching locally',
      build: build,
      setUp: () {
        stubList(all: NotificationPage(items: [notification()]));
        when(
          () => repo.markRead(any()),
        ).thenAnswer((_) async => const Right(null));
      },
      act: (cubit) async {
        await cubit.load();
        clearInteractions(repo);
        await cubit.markRead(notification());
      },
      verify: (_) {
        verify(() => repo.markRead('ntf_1')).called(1);
        verify(
          () => repo.list(
            isRead: any(named: 'isRead'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'an already-read notification is not re-sent',
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.markRead(notification(isRead: true));
      },
      verify: (_) => verifyNever(() => repo.markRead(any())),
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'mark-all-read clears the badge and resyncs',
      build: build,
      setUp: () {
        stubList(
          all: NotificationPage(items: [notification()]),
          unread: NotificationPage(items: [notification()]),
        );
        when(
          () => repo.markAllRead(),
        ).thenAnswer((_) async => const Right(null));
      },
      act: (cubit) async {
        await cubit.load();
        stubList(all: NotificationPage(items: [notification(isRead: true)]));
        await cubit.markAllRead();
      },
      verify: (cubit) {
        verify(() => repo.markAllRead()).called(1);
        expect(cubit.state.unreadCount, 0);
      },
    );
  });

  blocTest<NotificationsCubit, NotificationsState>(
    'a queue event refetches once the dispatcher has written the row',
    build: build,
    setUp: () => stubList(all: NotificationPage(items: [notification()])),
    act: (cubit) async {
      await cubit.load();
      clearInteractions(repo);
      events.add(
        const RealtimeEvent(
          type: 'queue.entry.updated.v1',
          resourceType: 'queue_entry',
          resourceId: 'que_1',
          version: 2,
          data: {},
        ),
      );
    },
    wait:
        NotificationsCubit.pushSettleDelay + const Duration(milliseconds: 300),
    verify: (_) => verify(
      () => repo.list(
        isRead: any(named: 'isRead'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).called(greaterThanOrEqualTo(1)),
  );
}
