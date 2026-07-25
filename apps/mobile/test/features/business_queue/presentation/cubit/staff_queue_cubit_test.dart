import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board_entry.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_command.dart';
import 'package:antrein/features/business_queue/domain/repositories/business_queue_repository.dart';
import 'package:antrein/features/business_queue/presentation/cubit/staff_queue_cubit.dart';
import 'package:antrein/features/customer_queue/customer_queue.dart'
    show QueueStatus;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockBusinessQueueRepository extends Mock
    implements BusinessQueueRepository {}

void main() {
  late MockBusinessQueueRepository repo;

  const waitingEntry = QueueBoardEntry(
    queueEntryId: 'que_w1',
    displayNumber: 'A012',
    bookingId: 'bkg_w1',
    status: QueueStatus.waiting,
    version: 2,
    customerName: 'Andi',
  );
  const board = QueueBoard(
    businessDate: '2026-07-26',
    outletId: 'out_1',
    isOpen: true,
    version: 18,
    waiting: [waitingEntry],
    skipped: [],
  );

  setUpAll(() => registerFallbackValue(''));
  setUp(() => repo = MockBusinessQueueRepository());

  void stubLoad() {
    when(
      () => repo.resolveOutletId(
        businessId: 'biz_1',
        membershipOutletIds: const [],
      ),
    ).thenAnswer((_) async => const Right('out_1'));
    when(
      () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
    ).thenAnswer((_) async => const Right(board));
  }

  blocTest<StaffQueueCubit, StaffQueueState>(
    'resolves the outlet then loads the board',
    build: () => StaffQueueCubit(repo),
    setUp: stubLoad,
    act: (cubit) =>
        cubit.load(businessId: 'biz_1', membershipOutletIds: const []),
    expect: () => const [
      StaffQueueState(status: BoardStatus.loading),
      StaffQueueState(status: BoardStatus.success, board: board),
    ],
  );

  blocTest<StaffQueueCubit, StaffQueueState>(
    'an owner with no assigned outlet still resolves via the primary outlet',
    build: () => StaffQueueCubit(repo),
    setUp: stubLoad,
    act: (cubit) =>
        cubit.load(businessId: 'biz_1', membershipOutletIds: const []),
    verify: (_) {
      verify(
        () => repo.resolveOutletId(
          businessId: 'biz_1',
          membershipOutletIds: const [],
        ),
      ).called(1);
    },
  );

  blocTest<StaffQueueCubit, StaffQueueState>(
    'a successful command re-reads the board (REST is authoritative)',
    build: () => StaffQueueCubit(repo),
    setUp: () {
      stubLoad();
      when(
        () => repo.runCommand(
          businessId: 'biz_1',
          queueEntryId: 'que_w1',
          command: QueueCommand.call,
          expectedVersion: 2,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => const Right(null));
    },
    act: (cubit) async {
      await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
      await cubit.runCommand(waitingEntry, QueueCommand.call);
    },
    verify: (cubit) {
      verify(
        () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
      ).called(2); // initial load + post-command resync
      expect(cubit.state.actingEntryId, isNull);
      expect(cubit.state.actionError, isNull);
    },
  );

  blocTest<StaffQueueCubit, StaffQueueState>(
    'a version conflict resyncs the board and flags the conflict',
    build: () => StaffQueueCubit(repo),
    setUp: () {
      stubLoad();
      when(
        () => repo.runCommand(
          businessId: 'biz_1',
          queueEntryId: 'que_w1',
          command: QueueCommand.call,
          expectedVersion: 2,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          ConflictFailure(
            'Queue changed',
            code: ApiErrorCodes.queueVersionConflict,
          ),
        ),
      );
    },
    act: (cubit) async {
      await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
      await cubit.runCommand(waitingEntry, QueueCommand.call);
    },
    verify: (cubit) {
      verify(
        () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
      ).called(2); // initial load + conflict resync
      expect(cubit.state.actionConflict, isTrue);
      expect(cubit.state.actingEntryId, isNull);
    },
  );
}
