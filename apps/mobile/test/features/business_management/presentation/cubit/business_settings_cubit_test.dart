import 'package:antrein/core/error/failures.dart';
import 'package:antrein/features/business_management/business_management.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockBusinessManagementRepository extends Mock
    implements BusinessManagementRepository {}

void main() {
  late MockBusinessManagementRepository repo;

  const business = ManagedBusiness(
    id: 'biz_1',
    name: 'AntreIn Barbershop',
    supportedPaymentOptions: [payAtLocationOption],
  );
  const outlet = ManagedOutlet(id: 'out_1', name: 'Main Outlet');

  setUpAll(() {
    registerFallbackValue(business);
    registerFallbackValue(outlet);
  });

  setUp(() {
    repo = MockBusinessManagementRepository();
    when(
      () => repo.getManagement(any()),
    ).thenAnswer((_) async => const Right(business));
    when(
      () => repo.getOutlet(any(), any()),
    ).thenAnswer((_) async => const Right(outlet));
    when(
      () => repo.updateBusiness(any(), any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => repo.updateOutlet(any(), any()),
    ).thenAnswer((_) async => const Right(null));
  });

  test('loads the business with its outlet', () async {
    final cubit = BusinessSettingsCubit(repo);
    await cubit.load('biz_1', 'out_1');

    expect(cubit.state.status, SettingsStatus.success);
    expect(cubit.state.business, business);
    expect(cubit.state.outlet, outlet);
    await cubit.close();
  });

  test('a failed outlet read still leaves the policies editable', () async {
    when(
      () => repo.getOutlet(any(), any()),
    ).thenAnswer((_) async => const Left(ServerFailure('No detail.')));

    final cubit = BusinessSettingsCubit(repo);
    await cubit.load('biz_1', 'out_1');

    expect(cubit.state.status, SettingsStatus.success);
    expect(cubit.state.outlet, isNull);
    await cubit.close();
  });

  test('one save writes the business then the outlet', () async {
    final cubit = BusinessSettingsCubit(repo);
    await cubit.load('biz_1', 'out_1');

    await cubit.save(business: business, outlet: outlet);

    expect(cubit.state.savedTick, 1);
    expect(cubit.state.message, isNull);
    verifyInOrder([
      () => repo.updateBusiness('biz_1', business),
      () => repo.updateOutlet('biz_1', outlet),
    ]);
    await cubit.close();
  });

  test('a rejected business write skips the outlet write', () async {
    when(() => repo.updateBusiness(any(), any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure('Bad option.', code: 'PAYMENT_OPTION_NOT_SUPPORTED'),
      ),
    );

    final cubit = BusinessSettingsCubit(repo);
    await cubit.load('biz_1', 'out_1');
    await cubit.save(business: business, outlet: outlet);

    expect(cubit.state.savedTick, 0);
    expect(cubit.state.message, 'Bad option.');
    verifyNever(() => repo.updateOutlet(any(), any()));
    await cubit.close();
  });

  test('an outlet that never loaded is not written', () async {
    when(
      () => repo.getOutlet(any(), any()),
    ).thenAnswer((_) async => const Right(null));

    final cubit = BusinessSettingsCubit(repo);
    await cubit.load('biz_1', 'out_1');
    await cubit.save(business: business);

    expect(cubit.state.savedTick, 1);
    verifyNever(() => repo.updateOutlet(any(), any()));
    await cubit.close();
  });
}
