import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/features/auth/domain/entities/user.dart';
import 'package:antrein/features/auth/domain/entities/user_role.dart';
import 'package:antrein/features/auth/domain/usecases/get_current_user.dart';
import 'package:antrein/features/auth/domain/usecases/register.dart';
import 'package:antrein/features/auth/domain/usecases/sign_in.dart';
import 'package:antrein/features/auth/domain/usecases/sign_out.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockSignIn extends Mock implements SignIn {}

class MockRegister extends Mock implements Register {}

class MockSignOut extends Mock implements SignOut {}

class MockGetCurrentUser extends Mock implements GetCurrentUser {}

void main() {
  late MockSignIn signIn;
  late MockRegister register;
  late MockSignOut signOut;
  late MockGetCurrentUser getCurrentUser;

  const user = User(
    id: 'usr_1',
    name: 'Oki',
    email: 'oki@example.com',
    roles: [UserRole.customer],
  );

  setUpAll(() {
    registerFallbackValue(const SignInParams(email: '', password: ''));
    registerFallbackValue(
      const RegisterParams(name: '', email: '', password: ''),
    );
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    signIn = MockSignIn();
    register = MockRegister();
    signOut = MockSignOut();
    getCurrentUser = MockGetCurrentUser();
  });

  AuthCubit build() => AuthCubit(signIn, register, signOut, getCurrentUser);

  group('signIn', () {
    blocTest<AuthCubit, AuthState>(
      'emits [loading, authenticated] on success',
      build: () {
        when(() => signIn(any())).thenAnswer((_) async => const Right(user));
        return build();
      },
      act: (cubit) =>
          cubit.signIn(email: 'oki@example.com', password: 'password123'),
      expect: () => const [AuthLoading(), AuthAuthenticated(user)],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [loading, error] on failure',
      build: () {
        when(
          () => signIn(any()),
        ).thenAnswer((_) async => const Left(AuthFailure('bad creds')));
        return build();
      },
      act: (cubit) => cubit.signIn(email: 'x@y.z', password: 'nope'),
      expect: () => const [AuthLoading(), AuthError('bad creds')],
    );
  });

  group('register', () {
    blocTest<AuthCubit, AuthState>(
      'authenticates just like sign-in',
      build: () {
        when(() => register(any())).thenAnswer((_) async => const Right(user));
        return build();
      },
      act: (cubit) => cubit.register(
        name: 'Oki',
        email: 'oki@example.com',
        password: 'password123',
      ),
      expect: () => const [AuthLoading(), AuthAuthenticated(user)],
    );
  });

  group('restoreSession', () {
    blocTest<AuthCubit, AuthState>(
      'authenticated when the session is valid',
      build: () {
        when(
          () => getCurrentUser(any()),
        ).thenAnswer((_) async => const Right(user));
        return build();
      },
      act: (cubit) => cubit.restoreSession(),
      expect: () => const [AuthAuthenticated(user)],
    );

    blocTest<AuthCubit, AuthState>(
      'stays initial on AuthFailure (dead session, no error flash)',
      build: () {
        when(
          () => getCurrentUser(any()),
        ).thenAnswer((_) async => const Left(AuthFailure('unauthenticated')));
        return build();
      },
      act: (cubit) => cubit.restoreSession(),
      expect: () => const [AuthInitial()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits error on a transient failure (not a silent logout)',
      build: () {
        when(
          () => getCurrentUser(any()),
        ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
        return build();
      },
      act: (cubit) => cubit.restoreSession(),
      expect: () => const [AuthError('offline')],
    );
  });

  group('signOut', () {
    blocTest<AuthCubit, AuthState>(
      'returns to initial',
      build: () {
        when(() => signOut(any())).thenAnswer((_) async => const Right(null));
        return build();
      },
      seed: () => const AuthAuthenticated(user),
      act: (cubit) => cubit.signOut(),
      expect: () => const [AuthInitial()],
    );
  });
}
