import 'package:antrein/core/error/failures.dart';
import 'package:antrein/features/discovery/domain/entities/business_summary.dart';
import 'package:antrein/features/discovery/domain/usecases/get_businesses.dart';
import 'package:antrein/features/discovery/presentation/cubit/discovery_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockGetBusinesses extends Mock implements GetBusinesses {}

void main() {
  late MockGetBusinesses getBusinesses;

  const businesses = [
    BusinessSummary(
      id: 'biz_1',
      name: 'Barber One',
      supportedPaymentOptions: ['pay_at_location'],
    ),
  ];

  setUpAll(() {
    registerFallbackValue(const GetBusinessesParams());
  });

  setUp(() {
    getBusinesses = MockGetBusinesses();
  });

  blocTest<DiscoveryCubit, DiscoveryState>(
    'loads businesses',
    build: () => DiscoveryCubit(getBusinesses),
    setUp: () => when(
      () => getBusinesses(any()),
    ).thenAnswer((_) async => const Right(businesses)),
    act: (cubit) => cubit.load(),
    expect: () => [
      const DiscoveryState.loading(),
      const DiscoveryState.loaded(businesses),
    ],
  );

  blocTest<DiscoveryCubit, DiscoveryState>(
    'maps an empty result to the empty state',
    build: () => DiscoveryCubit(getBusinesses),
    setUp: () => when(
      () => getBusinesses(any()),
    ).thenAnswer((_) async => const Right(<BusinessSummary>[])),
    act: (cubit) => cubit.load(),
    expect: () => [
      const DiscoveryState.loading(),
      const DiscoveryState.empty(),
    ],
  );

  blocTest<DiscoveryCubit, DiscoveryState>(
    'refresh keeps stale data on failure',
    build: () => DiscoveryCubit(getBusinesses),
    seed: () => const DiscoveryState.loaded(businesses),
    setUp: () => when(() => getBusinesses(any())).thenAnswer(
      (_) async => const Left(NetworkFailure('No internet connection.')),
    ),
    act: (cubit) => cubit.refresh(),
    expect: () => <DiscoveryState>[],
  );
}
