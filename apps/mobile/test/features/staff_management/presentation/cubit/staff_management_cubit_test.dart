import 'package:antrein/core/domain/money.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/features/service_management/service_management.dart';
import 'package:antrein/features/staff_management/staff_management.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockStaffManagementRepository extends Mock
    implements StaffManagementRepository {}

class MockServiceManagementRepository extends Mock
    implements ServiceManagementRepository {}

void main() {
  late MockStaffManagementRepository repo;
  late MockServiceManagementRepository services;

  const andi = ManagedStaff(id: 'stf_1', name: 'Andi', role: 'barber');
  const haircut = ManagedService(
    id: 'svc_1',
    name: 'Haircut',
    durationMinutes: 45,
    price: Money(50000),
  );
  const invite = StaffDraft(
    displayName: 'Budi',
    role: StaffRole.barber,
    email: 'budi@example.com',
  );

  setUpAll(() => registerFallbackValue(invite));

  setUp(() {
    repo = MockStaffManagementRepository();
    services = MockServiceManagementRepository();
    when(
      () => repo.listStaff(any()),
    ).thenAnswer((_) async => const Right([andi]));
    when(
      () => services.listServices(any()),
    ).thenAnswer((_) async => const Right([haircut]));
  });

  blocTest<StaffManagementCubit, StaffManagementState>(
    'loads the roster and the service options',
    build: () => StaffManagementCubit(repo, services),
    act: (cubit) => cubit.load('biz_1', outletId: 'out_1'),
    expect: () => [
      const StaffManagementState(status: StaffListStatus.loading),
      const StaffManagementState(
        status: StaffListStatus.success,
        staff: [andi],
        services: [ServiceOption(id: 'svc_1', name: 'Haircut')],
      ),
    ],
  );

  test('an invite assigns the board outlet and reports the code', () async {
    final cubit = StaffManagementCubit(repo, services);
    await cubit.load('biz_1', outletId: 'out_1');
    when(
      () => repo.inviteStaff(
        any(),
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async => const Right('inv_1'));

    final error = await cubit.save(invite);

    expect(error, isNull);
    // The member only joins the roster once they accept (§51), so nothing is
    // refetched — the id is surfaced instead.
    expect(cubit.state.invitationId, 'inv_1');
    expect(cubit.state.invitedEmail, 'budi@example.com');
    verify(() => repo.listStaff('biz_1')).called(1);

    final sent =
        verify(
              () => repo.inviteStaff(
                any(),
                captureAny(),
                idempotencyKey: any(named: 'idempotencyKey'),
              ),
            ).captured.single
            as StaffDraft;
    expect(sent.outletIds, ['out_1']);

    cubit.clearInvitation();
    expect(cubit.state.invitationId, isNull);
    await cubit.close();
  });

  test('an update refetches the roster', () async {
    final cubit = StaffManagementCubit(repo, services);
    await cubit.load('biz_1', outletId: 'out_1');
    when(
      () => repo.updateStaff(any(), any()),
    ).thenAnswer((_) async => const Right(null));

    final error = await cubit.save(
      const StaffDraft(
        id: 'stf_1',
        displayName: 'Andi',
        role: StaffRole.frontDesk,
      ),
    );

    expect(error, isNull);
    verify(() => repo.listStaff('biz_1')).called(2);
    await cubit.close();
  });

  test('a blocked deactivate keeps the backend reason', () async {
    final cubit = StaffManagementCubit(repo, services);
    await cubit.load('biz_1', outletId: 'out_1');
    when(() => repo.deactivateStaff(any(), any())).thenAnswer(
      (_) async => const Left(
        ConflictFailure(
          'Resolve 2 future bookings first.',
          code: 'STAFF_HAS_ACTIVE_BOOKINGS',
        ),
      ),
    );

    await cubit.deactivate('stf_1');

    expect(cubit.state.message, 'Resolve 2 future bookings first.');
    expect(cubit.state.actingStaffId, isNull);
    await cubit.close();
  });
}
