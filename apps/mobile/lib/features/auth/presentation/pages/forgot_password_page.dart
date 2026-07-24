import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/password_reset_cubit.dart';
import 'package:antrein/features/auth/presentation/widgets/auth_success_view.dart';
import 'package:antrein/features/auth/presentation/widgets/forgot_password_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The `/forgot-password` page (step 1). Owns a page-scoped [PasswordResetCubit]
/// (factory from DI) — the reset flow does not touch the app session.
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<PasswordResetCubit>(),
    child: const _ForgotPasswordView(),
  );
}

class _ForgotPasswordView extends StatelessWidget {
  const _ForgotPasswordView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle)),
      body: BlocConsumer<PasswordResetCubit, PasswordResetState>(
        listener: (context, state) {
          if (state is PasswordResetError) {
            context.showSnackBar(state.message);
          }
        },
        builder: (context, state) => switch (state) {
          PasswordResetSuccess() => AuthSuccessView(
            message: l10n.passwordResetEmailSent,
            actionLabel: l10n.enterResetToken,
            icon: Icons.mark_email_read_outlined,
            onAction: () => context.pushNamed(Routes.resetPassword.name),
          ),
          _ => ForgotPasswordForm(
            isLoading: state is PasswordResetLoading,
            onSubmit: (email) =>
                context.read<PasswordResetCubit>().requestReset(email: email),
          ),
        },
      ),
    );
  }
}
