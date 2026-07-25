import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_status.dart';
import 'package:antrein/features/customer_queue/domain/usecases/check_in.dart';
import 'package:antrein/features/customer_queue/presentation/cubit/check_in_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCheckIn extends Mock implements CheckIn {}

void main() {
  late MockCheckIn checkIn;

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
    registerFallbackValue(
      const CheckInParams(bookingId: '', idempotencyKey: ''),
    );
  });

  setUp(() => checkIn = MockCheckIn());

  blocTest<CheckInCubit, CheckInState>(
    'emits submitting then success with the queue entry',
    build: () => CheckInCubit(checkIn),
    setUp: () => when(
      () => checkIn(any()),
    ).thenAnswer((_) async => const Right(entry)),
    act: (cubit) => cubit.submit('bkg_1'),
    expect: () => const [
      CheckInState.submitting(),
      CheckInState.success(entry),
    ],
    verify: (_) {
      final params =
          verify(() => checkIn(captureAny())).captured.single as CheckInParams;
      expect(params.bookingId, 'bkg_1');
      expect(params.idempotencyKey, isNotEmpty);
    },
  );

  blocTest<CheckInCubit, CheckInState>(
    'surfaces the backend error code for localized copy (too early)',
    build: () => CheckInCubit(checkIn),
    setUp: () => when(() => checkIn(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure('Too early.', code: ApiErrorCodes.bookingCheckInTooEarly),
      ),
    ),
    act: (cubit) => cubit.submit('bkg_1'),
    expect: () => const [
      CheckInState.submitting(),
      CheckInState.error(
        'Too early.',
        code: ApiErrorCodes.bookingCheckInTooEarly,
      ),
    ],
  );

  blocTest<CheckInCubit, CheckInState>(
    'keeps the same key across an ambiguous transport-failure retry',
    build: () => CheckInCubit(checkIn),
    setUp: () {
      final answers = <Either<Failure, QueueEntry>>[
        const Left(NetworkFailure('Connection lost.')),
        const Right(entry),
      ];
      when(() => checkIn(any())).thenAnswer((_) async => answers.removeAt(0));
    },
    act: (cubit) async {
      await cubit.submit('bkg_1');
      await cubit.submit('bkg_1');
    },
    verify: (_) {
      final keys = verify(
        () => checkIn(captureAny()),
      ).captured.cast<CheckInParams>().map((p) => p.idempotencyKey).toList();
      expect(keys, hasLength(2));
      expect(keys[0], keys[1]);
    },
  );

  blocTest<CheckInCubit, CheckInState>(
    'rotates the key after a coded (definitive) rejection',
    build: () => CheckInCubit(checkIn),
    setUp: () {
      final answers = <Either<Failure, QueueEntry>>[
        const Left(
          ServerFailure(
            'Too early.',
            code: ApiErrorCodes.bookingCheckInTooEarly,
          ),
        ),
        const Right(entry),
      ];
      when(() => checkIn(any())).thenAnswer((_) async => answers.removeAt(0));
    },
    act: (cubit) async {
      await cubit.submit('bkg_1');
      await cubit.submit('bkg_1');
    },
    verify: (_) {
      final keys = verify(
        () => checkIn(captureAny()),
      ).captured.cast<CheckInParams>().map((p) => p.idempotencyKey).toList();
      expect(keys[0], isNot(keys[1]));
    },
  );
}
