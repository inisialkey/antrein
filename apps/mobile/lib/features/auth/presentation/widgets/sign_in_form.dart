import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/widgets/auth_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Dumb sign-in form: owns its controllers + validation, delegates the actual
/// actions to callbacks so it stays decoupled from the Cubit and the router.
class SignInForm extends StatefulWidget {
  const SignInForm({
    required this.isLoading,
    required this.onSubmit,
    required this.onRegister,
    required this.onForgotPassword,
    super.key,
  });

  final bool isLoading;
  final void Function(String email, String password) onSubmit;
  final VoidCallback onRegister;
  final VoidCallback onForgotPassword;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Dimens.space24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AuthHeader(subtitle: l10n.signInSubtitle),
            const Gap(Dimens.space24),
            AppTextField(
              label: l10n.email,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return l10n.emailRequired;
                if (!email.contains('@')) return l10n.emailInvalid;
                return null;
              },
            ),
            const Gap(Dimens.space12),
            AppTextField(
              label: l10n.password,
              controller: _password,
              obscureText: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) => (value == null || value.isEmpty)
                  ? l10n.passwordRequired
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.isLoading ? null : widget.onForgotPassword,
                child: Text(l10n.forgotPassword),
              ),
            ),
            const Gap(Dimens.space8),
            AppButton(
              label: l10n.signIn,
              loading: widget.isLoading,
              onPressed: _submit,
            ),
            const Gap(Dimens.space8),
            TextButton(
              onPressed: widget.isLoading ? null : widget.onRegister,
              child: Text(l10n.dontHaveAccount),
            ),
          ],
        ),
      ),
    );
  }
}
