import 'package:antrein/core/error/exceptions.dart';
import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late AuthRemoteDataSourceImpl ds;

  Response<dynamic> response(int status, Map<String, dynamic> body) => Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: body,
  );

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    dio = MockDio();
    ds = AuthRemoteDataSourceImpl(dio);
  });

  test('signIn unwraps the {success, data} envelope', () async {
    when(
      () => dio.post<dynamic>(ApiEndpoints.login, data: any(named: 'data')),
    ).thenAnswer(
      (_) async => response(200, {
        'success': true,
        'data': {
          'user': {
            'id': 'usr_1',
            'name': 'Oki',
            'email': 'o@e.com',
            'roles': ['customer'],
          },
          'session': {
            'accessToken': 'acc',
            'accessTokenExpiresAt': 't',
            'refreshToken': 'ref',
            'refreshTokenExpiresAt': 't',
          },
        },
        'meta': <String, dynamic>{},
      }),
    );

    final result = await ds.signIn(email: 'o@e.com', password: 'p');

    expect(result.user.id, 'usr_1');
    expect(result.session.accessToken, 'acc');
    expect(result.session.refreshToken, 'ref');
  });

  test('a 401 AUTH_INVALID_CREDENTIALS maps to AuthException', () async {
    when(
      () => dio.post<dynamic>(ApiEndpoints.login, data: any(named: 'data')),
    ).thenAnswer(
      (_) async => response(401, {
        'success': false,
        'error': {
          'code': 'AUTH_INVALID_CREDENTIALS',
          'message': 'Email or password is incorrect.',
        },
        'meta': <String, dynamic>{},
      }),
    );

    await expectLater(
      ds.signIn(email: 'o@e.com', password: 'bad'),
      throwsA(isA<AuthException>()),
    );
  });

  test(
    'a 409 AUTH_EMAIL_ALREADY_REGISTERED maps to ConflictException',
    () async {
      when(
        () =>
            dio.post<dynamic>(ApiEndpoints.register, data: any(named: 'data')),
      ).thenAnswer(
        (_) async => response(409, {
          'success': false,
          'error': {
            'code': 'AUTH_EMAIL_ALREADY_REGISTERED',
            'message': 'Email is already registered.',
          },
        }),
      );

      await expectLater(
        ds.register(name: 'n', email: 'e@x.com', password: 'password1'),
        throwsA(isA<ConflictException>()),
      );
    },
  );

  test('a transport connection error maps to NetworkException', () async {
    when(() => dio.get<dynamic>(ApiEndpoints.currentUser)).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.currentUser),
        type: DioExceptionType.connectionError,
      ),
    );

    await expectLater(ds.getCurrentUser(), throwsA(isA<NetworkException>()));
  });
}
