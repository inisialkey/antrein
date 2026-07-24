import 'package:antrein/core/error/exceptions.dart';
import 'package:antrein/core/error/failures.dart';
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

void main() {
  late MockRemote remote;
  late MockStorage storage;
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
    repo = AuthRepositoryImpl(remote, storage);
  });

  group('signIn', () {
    test('persists the token pair and returns the user on success', () async {
      when(
        () => remote.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
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
        () => storage.saveTokens(accessToken: 'acc', refreshToken: 'ref'),
      ).called(1);
    });

    test('maps AuthException → AuthFailure and does NOT save tokens', () async {
      when(
        () => remote.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
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

  test('register maps ConflictException → ConflictFailure', () async {
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

  test('signOut clears storage even when the server revoke throws', () async {
    when(() => storage.readRefreshToken()).thenAnswer((_) async => 'ref');
    when(
      () => remote.signOut(refreshToken: any(named: 'refreshToken')),
    ).thenThrow(const ServerException('server down'));
    when(() => storage.clear()).thenAnswer((_) async {});

    final result = await repo.signOut();

    expect(result.isRight(), isTrue);
    verify(() => storage.clear()).called(1);
  });
}
