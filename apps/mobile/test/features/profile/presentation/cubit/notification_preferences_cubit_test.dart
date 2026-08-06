import 'package:antrein/core/error/failures.dart';
import 'package:antrein/features/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late MockProfileRepository repo;

  const loaded = NotificationPreferences(marketing: true);

  setUpAll(() => registerFallbackValue(const NotificationPreferences()));

  setUp(() {
    repo = MockProfileRepository();
    when(
      () => repo.getPreferences(),
    ).thenAnswer((_) async => const Right(loaded));
    when(() => repo.updatePreferences(any())).thenAnswer(
      (invocation) async => Right(
        invocation.positionalArguments[0] as NotificationPreferences,
      ),
    );
  });

  test('loads the stored preferences', () async {
    final cubit = NotificationPreferencesCubit(repo);
    await cubit.load();

    expect(cubit.state.status, PreferencesStatus.success);
    expect(cubit.state.preferences, loaded);
    await cubit.close();
  });

  test('a failed read reports failure and keeps the defaults', () async {
    when(
      () => repo.getPreferences(),
    ).thenAnswer((_) async => const Left(ServerFailure('Offline.')));

    final cubit = NotificationPreferencesCubit(repo);
    await cubit.load();

    expect(cubit.state.status, PreferencesStatus.failure);
    expect(cubit.state.message, 'Offline.');
    await cubit.close();
  });

  test('a toggle writes the whole set and confirms', () async {
    final cubit = NotificationPreferencesCubit(repo);
    await cubit.load();

    await cubit.toggle(loaded.copyWith(queueUpdates: false));

    verify(
      () => repo.updatePreferences(
        const NotificationPreferences(queueUpdates: false, marketing: true),
      ),
    ).called(1);
    expect(cubit.state.preferences.queueUpdates, isFalse);
    expect(cubit.state.savedTick, 1);
    await cubit.close();
  });

  test('a rejected toggle snaps the switch back', () async {
    when(() => repo.updatePreferences(any())).thenAnswer(
      (_) async => const Left(ServerFailure('Server rejected it.')),
    );

    final cubit = NotificationPreferencesCubit(repo);
    await cubit.load();
    await cubit.toggle(loaded.copyWith(marketing: false));

    expect(cubit.state.preferences, loaded);
    expect(cubit.state.message, 'Server rejected it.');
    expect(cubit.state.savedTick, 0);
    await cubit.close();
  });
}
