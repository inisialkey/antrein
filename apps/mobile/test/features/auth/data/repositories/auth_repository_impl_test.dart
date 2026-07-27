import 'package:antrein/core/device/device_id_store.dart';
import 'package:antrein/core/error/exceptions.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/push/push_service.dart';
import 'package:antrein/core/storage/token_storage.dart';
import 'package:antrein/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:antrein/features/auth/data/models/auth_result.dart';
import 'package:antrein/features/auth/data/models/session_tokens_model.dart';
import 'package:antrein/features/auth/data/models/user_model.dart';
import 'package:antrein/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements AuthRemoteDataSource {}

class MockStorage extends Mock implements TokenStorage {}

class MockDeviceIds extends Mock implements DeviceIdStore {}

class MockPush extends Mock implements PushService {}

void main() {
  late MockRemote remote;
  late MockStorage storage;
  late MockDeviceIds deviceIds;
  late MockPush push;
  late AuthRepositoryImpl repo;

  const authResult = AuthResult(
    user: UserModel(
      id: 'usr_1',
      name: 'Oki',
      email: 'o@e.com',
      roles: ['customer'],
    ),
    session: SessionTokensModel(
      accessToken: 'acc',
      accessTokenExpiresAt: 't1',
      refreshToken: 'ref',
      refreshTokenExpiresAt: 't2',
    ),
  );

  setUp(() {
    remote = MockRemote();
    storage = MockStorage();
    deviceIds = MockDeviceIds();
    push = MockPush();
    when(() => deviceIds.obtain()).thenAnswer((_) async => 'dev_TEST');
    when(() => push.pushToken).thenReturn('sub_TOKEN');
    when(
      () => remote.registerDevice(
        deviceId: any(named: 'deviceId'),
        platform: any(named: 'platform'),
        locale: any(named: 'locale'),
        pushToken: any(named: 'pushToken'),
      ),
    ).thenAnswer((_) async {});
    repo = AuthRepositoryImpl(remote, storage, deviceIds, push);
  });

  group('signIn', () {
    test('sends the device identity, persists tokens, returns user', () async {
      when(
        () => remote.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceId: any(named: 'deviceId'),
          platform: any(named: 'platform'),
        ),
      ).thenAnswer((_) async => authResult);
      when(
        () => storage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async {});

      final result = await repo.signIn(email: 'o@e.com', password: 'password1');

      expect(result.isRight(), isTrue);
      result.match((_) => fail('expected Right'), (u) => expect(u.id, 'usr_1'));
      verify(
        () => remote.signIn(
          email: 'o@e.com',
          password: 'password1',
          deviceId: 'dev_TEST',
          platform: any(named: 'platform'),
        ),
      ).called(1);
      verify(
        () => storage.saveTokens(accessToken: 'acc', refreshToken: 'ref'),
      ).called(1);
      // Follow-up PUT uploads the OneSignal subscription id as the pushToken.
      verify(
        () => remote.registerDevice(
          deviceId: 'dev_TEST',
          platform: any(named: 'platform'),
          locale: any(named: 'locale'),
          pushToken: 'sub_TOKEN',
        ),
      ).called(1);
    });

    test('maps AuthException → AuthFailure and does NOT save tokens', () async {
      when(
        () => remote.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceId: any(named: 'deviceId'),
          platform: any(named: 'platform'),
        ),
      ).thenThrow(const AuthException('bad credentials'));

      final result = await repo.signIn(email: 'x', password: 'y');

      result.match(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
      verifyNever(
        () => storage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
    });
  });

  group('register', () {
    test('registers the device after success, best-effort', () async {
      when(
        () => remote.register(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          phoneNumber: any(named: 'phoneNumber'),
        ),
      ).thenAnswer((_) async => authResult);
      when(
        () => storage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async {});
      // Device registration failing must not fail the auth flow.
      when(
        () => remote.registerDevice(
          deviceId: any(named: 'deviceId'),
          platform: any(named: 'platform'),
          locale: any(named: 'locale'),
          pushToken: any(named: 'pushToken'),
        ),
      ).thenThrow(const ServerException('down'));

      final result = await repo.register(name: 'n', email: 'e', password: 'p');

      expect(result.isRight(), isTrue);
      verify(
        () => remote.registerDevice(
          deviceId: 'dev_TEST',
          platform: any(named: 'platform'),
          locale: any(named: 'locale'),
          pushToken: any(named: 'pushToken'),
        ),
      ).called(1);
    });

    test('maps ConflictException → ConflictFailure', () async {
      when(
        () => remote.register(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          phoneNumber: any(named: 'phoneNumber'),
        ),
      ).thenThrow(const ConflictException('email already registered'));

      final result = await repo.register(name: 'n', email: 'e', password: 'p');

      result.match(
        (f) => expect(f, isA<ConflictFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  test('signOut passes the deviceId and clears storage even when the server '
      'revoke throws', () async {
    when(() => storage.readRefreshToken()).thenAnswer((_) async => 'ref');
    when(
      () => remote.signOut(
        refreshToken: any(named: 'refreshToken'),
        deviceId: any(named: 'deviceId'),
      ),
    ).thenThrow(const ServerException('server down'));
    when(() => storage.clear()).thenAnswer((_) async {});

    final result = await repo.signOut();

    expect(result.isRight(), isTrue);
    verify(() => storage.clear()).called(1);
  });
}
