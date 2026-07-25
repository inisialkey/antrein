import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_status.dart';
import 'package:antrein/features/customer_queue/domain/usecases/get_customer_queue.dart';
import 'package:antrein/features/customer_queue/presentation/cubit/customer_queue_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockGetCustomerQueue extends Mock implements GetCustomerQueue {}

void main() {
  late MockGetCustomerQueue getQueue;

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

  setUp(() => getQueue = MockGetCustomerQueue());

  blocTest<CustomerQueueCubit, CustomerQueueState>(
    'loads the queue position',
    build: () => CustomerQueueCubit(getQueue),
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
    build: () => CustomerQueueCubit(getQueue),
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
    build: () => CustomerQueueCubit(getQueue),
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
}
