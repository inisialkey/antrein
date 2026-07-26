import 'dart:async';

import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/core/realtime/realtime_client.dart';
import 'package:antrein/core/realtime/realtime_event.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_status.dart';
import 'package:antrein/features/customer_queue/domain/usecases/get_customer_queue.dart';
import 'package:antrein/features/customer_queue/presentation/cubit/customer_queue_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockGetCustomerQueue extends Mock implements GetCustomerQueue {}

class MockRealtimeClient extends Mock implements RealtimeClient {}

void main() {
  late MockGetCustomerQueue getQueue;
  late MockRealtimeClient realtime;
  late StreamController<RealtimeEvent> events;
  late StreamController<void> connections;

  const entry = QueueEntry(
    id: 'que_1',
    bookingId: 'bkg_1',
    businessDate: '2026-07-22',
    queueNumber: 12,
    displayNumber: 'A012',
    status: QueueStatus.waiting,
    peopleAhead: 3,
    estimatedWaitMinutes: 45,
  );

  setUpAll(() {
    registerFallbackValue(const GetCustomerQueueParams(bookingId: ''));
  });

  setUp(() {
    getQueue = MockGetCustomerQueue();
    realtime = MockRealtimeClient();
    events = StreamController<RealtimeEvent>.broadcast();
    connections = StreamController<void>.broadcast();
    when(() => realtime.events).thenAnswer((_) => events.stream);
    when(() => realtime.connections).thenAnswer((_) => connections.stream);
    when(() => realtime.isConnected).thenReturn(false);
    when(() => realtime.connect()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await events.close();
    await connections.close();
  });

  CustomerQueueCubit build() => CustomerQueueCubit(getQueue, realtime);

  blocTest<CustomerQueueCubit, CustomerQueueState>(
    'loads the queue position',
    build: build,
    setUp: () =>
        when(() => getQueue(any())).thenAnswer((_) async => const Right(entry)),
    act: (cubit) => cubit.load('bkg_1'),
    expect: () => const [
      CustomerQueueState(status: QueueLoadStatus.loading),
      CustomerQueueState(status: QueueLoadStatus.success, entry: entry),
    ],
  );

  blocTest<CustomerQueueCubit, CustomerQueueState>(
    'maps QUEUE_ENTRY_NOT_FOUND to the empty state (not yet checked in)',
    build: build,
    setUp: () => when(() => getQueue(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure('Not found', code: ApiErrorCodes.queueEntryNotFound),
      ),
    ),
    act: (cubit) => cubit.load('bkg_1'),
    expect: () => const [
      CustomerQueueState(status: QueueLoadStatus.loading),
      CustomerQueueState(status: QueueLoadStatus.empty),
    ],
  );

  blocTest<CustomerQueueCubit, CustomerQueueState>(
    'a generic failure surfaces the message',
    build: build,
    setUp: () => when(() => getQueue(any())).thenAnswer(
      (_) async => const Left(NetworkFailure('No internet connection.')),
    ),
    act: (cubit) => cubit.load('bkg_1'),
    expect: () => const [
      CustomerQueueState(status: QueueLoadStatus.loading),
      CustomerQueueState(
        status: QueueLoadStatus.failure,
        message: 'No internet connection.',
      ),
    ],
  );

  blocTest<CustomerQueueCubit, CustomerQueueState>(
    'a realtime queue event for this booking triggers a REST refetch',
    build: build,
    setUp: () =>
        when(() => getQueue(any())).thenAnswer((_) async => const Right(entry)),
    act: (cubit) async {
      await cubit.load('bkg_1');
      events.add(
        const RealtimeEvent(
          type: 'queue.entry.updated.v1',
          resourceType: 'queue_entry',
          resourceId: 'que_1',
          version: 2,
          data: {'bookingId': 'bkg_1'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
    verify: (_) {
      verify(() => getQueue(any())).called(2); // initial load + event refetch
    },
  );

  blocTest<CustomerQueueCubit, CustomerQueueState>(
    'ignores a realtime event for a different booking',
    build: build,
    setUp: () =>
        when(() => getQueue(any())).thenAnswer((_) async => const Right(entry)),
    act: (cubit) async {
      await cubit.load('bkg_1');
      events.add(
        const RealtimeEvent(
          type: 'queue.entry.updated.v1',
          resourceType: 'queue_entry',
          resourceId: 'que_other',
          version: 2,
          data: {'bookingId': 'bkg_other'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
    verify: (_) {
      verify(() => getQueue(any())).called(1); // load only — event filtered out
    },
  );
}
