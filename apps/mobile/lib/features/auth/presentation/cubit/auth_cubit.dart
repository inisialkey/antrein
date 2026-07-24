import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/features/auth/domain/entities/user.dart';
import 'package:antrein/features/auth/domain/usecases/get_current_user.dart';
import 'package:antrein/features/auth/domain/usecases/register.dart';
import 'package:antrein/features/auth/domain/usecases/sign_in.dart';
import 'package:antrein/features/auth/domain/usecases/sign_out.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'auth_cubit.freezed.dart';
part 'auth_state.dart';

/// The one app-lifetime auth/session Cubit. Its state drives the router redirect
/// (see `AppRouter`): `AuthAuthenticated` unlocks the shells, anything else keeps
/// the user in the auth flow. Register authenticates just like sign-in; the
/// separate password-reset flow lives in `PasswordResetCubit`.
@injectable
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._signIn, this._register, this._signOut, this._getCurrentUser)
    : super(const AuthState.initial());

  final SignIn _signIn;
  final Register _register;
  final SignOut _signOut;
  final GetCurrentUser _getCurrentUser;

  Future<void> signIn({required String email, required String password}) async {
    emit(const AuthState.loading());
    final result = await _signIn(
      SignInParams(email: email, password: password),
    );
    result.match(
      (failure) => emit(AuthState.error(failure.message)),
      (user) => emit(AuthState.authenticated(user)),
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    emit(const AuthState.loading());
    final result = await _register(
      RegisterParams(
        name: name,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
      ),
    );
    result.match(
      (failure) => emit(AuthState.error(failure.message)),
      (user) => emit(AuthState.authenticated(user)),
    );
  }

  Future<void> restoreSession() async {
    final result = await _getCurrentUser(const NoParams());
    result.match(
      // Only a dead session logs out; a transient failure (offline, server
      // down) surfaces as an error so the UI can say "unreachable", not
      // silently pretend the user signed out.
      (failure) => emit(
        failure is AuthFailure
            ? const AuthState.initial()
            : AuthState.error(failure.message),
      ),
      (user) => emit(AuthState.authenticated(user)),
    );
  }

  Future<void> signOut() async {
    await _signOut(const NoParams());
    emit(const AuthState.initial());
  }
}
