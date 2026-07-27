import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/features/auth/presentation/widgets/register_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The `/register` page. Register authenticates like sign-in (shares the
/// app-scoped [AuthCubit]); on success the router redirect moves to the home.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text(context.l10n.createAccount)),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            context.showSnackBar(state.message);
          }
        },
        builder: (context, state) => RegisterForm(
          isLoading: state is AuthLoading,
          onSubmit: (name, email, phoneNumber, password) =>
              context.read<AuthCubit>().register(
                name: name,
                email: email,
                phoneNumber: phoneNumber,
                password: password,
              ),
          onSignIn: () => context.goNamed(Routes.login.name),
        ),
      ),
    );
  }
}
