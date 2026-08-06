import 'package:antrein/core/domain/money.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/files/file_upload_repository.dart';
import 'package:antrein/features/service_management/service_management.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockServiceManagementRepository extends Mock
    implements ServiceManagementRepository {}

class MockFileUploadRepository extends Mock implements FileUploadRepository {}

void main() {
  late MockServiceManagementRepository repo;
  late final files = MockFileUploadRepository();

  const haircut = ManagedService(
    id: 'svc_1',
    name: 'Haircut',
    durationMinutes: 45,
    price: Money(50000),
  );
  const draft = ServiceDraft(
    name: 'Haircut',
    durationMinutes: 45,
    priceAmount: 50000,
  );

  setUpAll(() => registerFallbackValue(draft));

  setUp(() {
    repo = MockServiceManagementRepository();
    when(
      () => repo.listServices(any()),
    ).thenAnswer((_) async => const Right([haircut]));
    when(
      () => repo.listStaffOptions(any()),
    ).thenAnswer(
      (_) async => const Right([StaffOption(id: 'stf_1', name: 'Andi')]),
    );
  });

  blocTest<ServiceManagementCubit, ServiceManagementState>(
    'loads the catalog and the eligibility options',
    build: () => ServiceManagementCubit(repo, files),
    act: (cubit) => cubit.load('biz_1'),
    expect: () => [
      const ServiceManagementState(status: ServiceListStatus.loading),
      const ServiceManagementState(
        status: ServiceListStatus.success,
        services: [haircut],
        staff: [StaffOption(id: 'stf_1', name: 'Andi')],
      ),
    ],
  );

  blocTest<ServiceManagementCubit, ServiceManagementState>(
    'a failed catalog read surfaces the message',
    build: () => ServiceManagementCubit(repo, files),
    setUp: () => when(
      () => repo.listServices(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('Not a member.'))),
    act: (cubit) => cubit.load('biz_1'),
    expect: () => [
      const ServiceManagementState(status: ServiceListStatus.loading),
      const ServiceManagementState(
        status: ServiceListStatus.failure,
        message: 'Not a member.',
      ),
    ],
  );

  test(
    'a create keeps its key across transport retries, drops a rejection',
    () async {
      final cubit = ServiceManagementCubit(repo, files);
      await cubit.load('biz_1');

      when(
        () => repo.createService(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => const Left(NetworkFailure('Offline.')));
      await cubit.save(draft);
      await cubit.save(draft);

      when(
        () => repo.createService(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async =>
            const Left(ConflictFailure('Taken.', code: 'SERVICE_NAME_EXISTS')),
      );
      await cubit.save(draft);
      await cubit.save(draft);

      final keys = verify(
        () => repo.createService(
          any(),
          any(),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured.cast<String>();

      expect(keys, hasLength(4));
      // Transport failures may replay the same submission…
      expect(keys[1], keys[0]);
      expect(keys[2], keys[0]);
      // …but the backend stored the coded rejection against that key.
      expect(keys[3], isNot(keys[2]));
      await cubit.close();
    },
  );

  test('an update reloads the catalog and needs no key', () async {
    final cubit = ServiceManagementCubit(repo, files);
    await cubit.load('biz_1');
    when(
      () => repo.updateService(any(), any()),
    ).thenAnswer((_) async => const Right(null));

    final error = await cubit.save(
      const ServiceDraft(
        id: 'svc_1',
        name: 'Haircut Deluxe',
        durationMinutes: 60,
        priceAmount: 80000,
      ),
    );

    expect(error, isNull);
    verifyNever(
      () => repo.createService(
        any(),
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
    verify(() => repo.listServices('biz_1')).called(2);
    await cubit.close();
  });

  blocTest<ServiceManagementCubit, ServiceManagementState>(
    'a failed deactivate leaves the row unlocked and reports why',
    build: () => ServiceManagementCubit(repo, files),
    setUp: () => when(
      () => repo.deactivateService(any(), any()),
    ).thenAnswer((_) async => const Left(ServerFailure('Nope.'))),
    act: (cubit) async {
      await cubit.load('biz_1');
      await cubit.deactivate('svc_1');
    },
    skip: 2,
    expect: () => [
      const ServiceManagementState(
        status: ServiceListStatus.success,
        services: [haircut],
        staff: [StaffOption(id: 'stf_1', name: 'Andi')],
        actingServiceId: 'svc_1',
      ),
      const ServiceManagementState(
        status: ServiceListStatus.success,
        services: [haircut],
        staff: [StaffOption(id: 'stf_1', name: 'Andi')],
        message: 'Nope.',
      ),
    ],
  );
}
