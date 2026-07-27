import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/features/auth/presentation/widgets/sign_in_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The `/login` page. Uses the app-scoped [AuthCubit] (provided above
/// `MaterialApp.router`); on success the router redirect moves to the role home.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text(context.l10n.signIn)),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            context.showSnackBar(state.message);
          }
        },
        builder: (context, state) => SignInForm(
          isLoading: state is AuthLoading,
          onSubmit: (email, password) => context.read<AuthCubit>().signIn(
            email: email,
            password: password,
          ),
          onRegister: () => context.pushNamed(Routes.register.name),
          onForgotPassword: () => context.pushNamed(Routes.forgotPassword.name),
        ),
      ),
    );
  }
}
