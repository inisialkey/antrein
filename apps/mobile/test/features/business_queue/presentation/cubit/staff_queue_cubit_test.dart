import 'dart:async';

import 'package:antrein/core/domain/money.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/core/realtime/realtime_client.dart';
import 'package:antrein/core/realtime/realtime_event.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board_entry.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_command.dart';
import 'package:antrein/features/business_queue/domain/repositories/business_queue_repository.dart';
import 'package:antrein/features/business_queue/presentation/cubit/staff_queue_cubit.dart';
import 'package:antrein/features/customer_queue/customer_queue.dart'
    show QueueStatus;
import 'package:antrein/features/discovery/domain/entities/service_item.dart';
import 'package:antrein/features/discovery/domain/entities/staff_member.dart';
import 'package:antrein/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockBusinessQueueRepository extends Mock
    implements BusinessQueueRepository {}

class MockRealtimeClient extends Mock implements RealtimeClient {}

class MockDiscoveryRepository extends Mock implements DiscoveryRepository {}

void main() {
  late MockBusinessQueueRepository repo;
  late MockRealtimeClient realtime;
  late MockDiscoveryRepository discovery;
  late StreamController<RealtimeEvent> events;
  late StreamController<void> connections;

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
  const secondWaiting = QueueBoardEntry(
    queueEntryId: 'que_w2',
    displayNumber: 'A013',
    bookingId: 'bkg_w2',
    status: QueueStatus.waiting,
    version: 1,
  );
  const skippedEntry = QueueBoardEntry(
    queueEntryId: 'que_s1',
    displayNumber: 'A010',
    bookingId: 'bkg_s1',
    status: QueueStatus.skipped,
    version: 3,
  );
  const reorderBoard = QueueBoard(
    businessDate: '2026-07-26',
    outletId: 'out_1',
    isOpen: true,
    version: 18,
    waiting: [waitingEntry, secondWaiting],
    skipped: [skippedEntry],
  );
  const service = ServiceItem(
    id: 'svc_1',
    name: 'Haircut',
    durationMinutes: 30,
    price: Money(50000),
  );

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    repo = MockBusinessQueueRepository();
    realtime = MockRealtimeClient();
    discovery = MockDiscoveryRepository();
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

  StaffQueueCubit build() => StaffQueueCubit(repo, realtime, discovery);

  void stubLoad([QueueBoard initial = board]) {
    when(
      () => repo.resolveOutletId(
        businessId: 'biz_1',
        membershipOutletIds: const [],
      ),
    ).thenAnswer((_) async => Right(initial.outletId));
    when(
      () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
    ).thenAnswer((_) async => Right(initial));
  }

  blocTest<StaffQueueCubit, StaffQueueState>(
    'resolves the outlet then loads the board',
    build: build,
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
    build: build,
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
    build: build,
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
    build: build,
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

  blocTest<StaffQueueCubit, StaffQueueState>(
    'a snapshot event for the outlet refreshes the board',
    build: build,
    setUp: stubLoad,
    act: (cubit) async {
      await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
      events.add(
        const RealtimeEvent(
          type: 'queue.snapshot.updated.v1',
          resourceType: 'outlet_queue',
          resourceId: 'out_1:2026-07-26',
          version: 19,
          data: {'outletId': 'out_1'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
    verify: (_) {
      verify(
        () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
      ).called(2); // initial load + snapshot-event resync
    },
  );

  blocTest<StaffQueueCubit, StaffQueueState>(
    're-joins the outlet room and resyncs on (re)connect',
    build: build,
    setUp: stubLoad,
    act: (cubit) async {
      await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
      connections.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
    verify: (_) {
      verify(
        () => realtime.subscribeOutletQueue('out_1', '2026-07-26'),
      ).called(1);
      verify(
        () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
      ).called(2); // initial load + reconnect resync
    },
  );

  group('start-service staff picker (§87)', () {
    blocTest<StaffQueueCubit, StaffQueueState>(
      'loads the barbers once and drops inactive ones',
      build: build,
      setUp: () {
        stubLoad();
        when(() => discovery.listStaff('biz_1')).thenAnswer(
          (_) async => const Right([
            StaffMember(id: 'stf_1', name: 'Andi'),
            StaffMember(id: 'stf_2', name: 'Sinta', isActive: false),
          ]),
        );
      },
      act: (cubit) async {
        await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
        await cubit.loadStaffOptions();
        await cubit.loadStaffOptions();
      },
      verify: (cubit) {
        verify(() => discovery.listStaff('biz_1')).called(1);
        expect(cubit.state.staffOptions, const [
          StaffMember(id: 'stf_1', name: 'Andi'),
        ]);
        expect(cubit.state.isLoadingStaff, isFalse);
      },
    );

    // The bug this guards: a walk-in entry carries no staffId, so omitting it
    // here makes the backend reject every start with STAFF_NOT_AVAILABLE.
    blocTest<StaffQueueCubit, StaffQueueState>(
      'forwards the picked barber to the start command',
      build: build,
      setUp: () {
        stubLoad();
        when(
          () => repo.runCommand(
            businessId: 'biz_1',
            queueEntryId: 'que_w1',
            command: QueueCommand.startService,
            expectedVersion: 2,
            idempotencyKey: any(named: 'idempotencyKey'),
            staffId: 'stf_1',
          ),
        ).thenAnswer((_) async => const Right(null));
      },
      act: (cubit) async {
        await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
        await cubit.runCommand(
          waitingEntry,
          QueueCommand.startService,
          staffId: 'stf_1',
        );
      },
      verify: (cubit) {
        verify(
          () => repo.runCommand(
            businessId: 'biz_1',
            queueEntryId: 'que_w1',
            command: QueueCommand.startService,
            expectedVersion: 2,
            idempotencyKey: any(named: 'idempotencyKey'),
            staffId: 'stf_1',
          ),
        ).called(1);
        expect(cubit.state.actionError, isNull);
      },
    );
  });

  group('walk-in (§67)', () {
    blocTest<StaffQueueCubit, StaffQueueState>(
      'loads the service list once and caches it',
      build: build,
      setUp: () {
        stubLoad();
        when(
          () => discovery.listServices('biz_1'),
        ).thenAnswer((_) async => const Right([service]));
      },
      act: (cubit) async {
        await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
        await cubit.loadWalkInServices();
        await cubit.loadWalkInServices();
      },
      verify: (cubit) {
        verify(() => discovery.listServices('biz_1')).called(1);
        expect(cubit.state.walkInServices, const [service]);
        expect(cubit.state.isLoadingServices, isFalse);
      },
    );

    blocTest<StaffQueueCubit, StaffQueueState>(
      'a created walk-in exposes its display number and resyncs the board',
      build: build,
      setUp: () {
        stubLoad();
        when(
          () => repo.createWalkIn(
            businessId: 'biz_1',
            outletId: 'out_1',
            serviceId: 'svc_1',
            customerName: 'Budi',
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async => const Right('A014'));
      },
      act: (cubit) async {
        await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
        await cubit.createWalkIn(customerName: 'Budi', serviceId: 'svc_1');
      },
      verify: (cubit) {
        expect(cubit.state.walkInCreatedNumber, 'A014');
        expect(cubit.state.isCreatingWalkIn, isFalse);
        verify(
          () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
        ).called(2); // initial load + post-create resync
      },
    );

    blocTest<StaffQueueCubit, StaffQueueState>(
      'a failed walk-in surfaces an action error',
      build: build,
      setUp: () {
        stubLoad();
        when(
          () => repo.createWalkIn(
            businessId: 'biz_1',
            outletId: 'out_1',
            serviceId: 'svc_1',
            customerName: 'Budi',
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async => const Left(ServerFailure('Queue closed')));
      },
      act: (cubit) async {
        await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
        await cubit.createWalkIn(customerName: 'Budi', serviceId: 'svc_1');
      },
      verify: (cubit) {
        expect(cubit.state.actionError, 'Queue closed');
        expect(cubit.state.walkInCreatedNumber, isNull);
        expect(cubit.state.isCreatingWalkIn, isFalse);
      },
    );
  });

  group('reorder (§90)', () {
    blocTest<StaffQueueCubit, StaffQueueState>(
      'moveWaiting reorders locally; commitReorder sends the exact '
      'waiting+skipped id set with the aggregate version',
      build: build,
      setUp: () {
        stubLoad(reorderBoard);
        when(
          () => repo.reorderQueue(
            businessId: 'biz_1',
            outletId: 'out_1',
            businessDate: '2026-07-26',
            expectedQueueVersion: 18,
            orderedQueueEntryIds: const ['que_w2', 'que_w1', 'que_s1'],
            reason: 'Priority arrived',
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async => const Right(null));
      },
      act: (cubit) async {
        await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
        cubit.moveWaiting(0, 1);
        expect(
          cubit.state.board!.waiting.map((e) => e.queueEntryId),
          ['que_w2', 'que_w1'],
        );
        expect(cubit.state.hasPendingReorder, isTrue);
        await cubit.commitReorder('Priority arrived');
      },
      verify: (cubit) {
        expect(cubit.state.hasPendingReorder, isFalse);
        expect(cubit.state.isReordering, isFalse);
        expect(cubit.state.actionError, isNull);
        verify(
          () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
        ).called(2); // initial load + post-reorder resync
      },
    );

    blocTest<StaffQueueCubit, StaffQueueState>(
      'a reorder version conflict resyncs the board and flags the conflict',
      build: build,
      setUp: () {
        stubLoad(reorderBoard);
        when(
          () => repo.reorderQueue(
            businessId: 'biz_1',
            outletId: 'out_1',
            businessDate: '2026-07-26',
            expectedQueueVersion: 18,
            orderedQueueEntryIds: any(named: 'orderedQueueEntryIds'),
            reason: any(named: 'reason'),
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
        cubit.moveWaiting(0, 1);
        await cubit.commitReorder('Priority arrived');
      },
      verify: (cubit) {
        expect(cubit.state.actionConflict, isTrue);
        expect(cubit.state.hasPendingReorder, isFalse);
        verify(
          () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
        ).called(2); // initial load + conflict resync
      },
    );

    blocTest<StaffQueueCubit, StaffQueueState>(
      'cancelReorder restores the server order',
      build: build,
      setUp: () => stubLoad(reorderBoard),
      act: (cubit) async {
        await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
        cubit.moveWaiting(0, 1);
        await cubit.cancelReorder();
      },
      verify: (cubit) {
        expect(cubit.state.hasPendingReorder, isFalse);
        expect(
          cubit.state.board!.waiting.map((e) => e.queueEntryId),
          ['que_w1', 'que_w2'],
        );
        verifyNever(
          () => repo.reorderQueue(
            businessId: any(named: 'businessId'),
            outletId: any(named: 'outletId'),
            businessDate: any(named: 'businessDate'),
            expectedQueueVersion: any(named: 'expectedQueueVersion'),
            orderedQueueEntryIds: any(named: 'orderedQueueEntryIds'),
            reason: any(named: 'reason'),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        );
        verify(
          () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
        ).called(2); // initial load + cancel restore
      },
    );

    blocTest<StaffQueueCubit, StaffQueueState>(
      'a pending reorder blocks background refreshes from clobbering the '
      'optimistic order',
      build: build,
      setUp: () => stubLoad(reorderBoard),
      act: (cubit) async {
        await cubit.load(businessId: 'biz_1', membershipOutletIds: const []);
        cubit.moveWaiting(0, 1);
        await cubit.refresh();
      },
      verify: (cubit) {
        expect(
          cubit.state.board!.waiting.map((e) => e.queueEntryId),
          ['que_w2', 'que_w1'],
        );
        verify(
          () => repo.getBoard(businessId: 'biz_1', outletId: 'out_1'),
        ).called(1); // initial load only — refresh skipped while pending
      },
    );
  });
}
