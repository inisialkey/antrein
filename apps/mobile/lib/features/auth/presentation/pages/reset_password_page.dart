import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/password_reset_cubit.dart';
import 'package:antrein/features/auth/presentation/widgets/auth_success_view.dart';
import 'package:antrein/features/auth/presentation/widgets/reset_password_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The `/reset-password` page (step 2). [token] pre-fills when opened from a
/// reset deep link. On success the user returns to sign-in (the backend has
/// revoked all sessions).
class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key, this.token});

  final String? token;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<PasswordResetCubit>(),
    child: _ResetPasswordView(initialToken: token),
  );
}

class _ResetPasswordView extends StatelessWidget {
  const _ResetPasswordView({this.initialToken});

  final String? initialToken;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.resetPasswordTitle)),
      body: BlocConsumer<PasswordResetCubit, PasswordResetState>(
        listener: (context, state) {
          if (state is PasswordResetError) {
            context.showSnackBar(state.message);
          }
        },
        builder: (context, state) => switch (state) {
          PasswordResetSuccess() => AuthSuccessView(
            message: l10n.passwordResetSuccess,
            actionLabel: l10n.backToSignIn,
            onAction: () => context.goNamed(Routes.login.name),
          ),
          _ => ResetPasswordForm(
            isLoading: state is PasswordResetLoading,
            initialToken: initialToken,
            onSubmit: (token, newPassword) => context
                .read<PasswordResetCubit>()
                .confirmReset(token: token, newPassword: newPassword),
          ),
        },
      ),
    );
  }
}
