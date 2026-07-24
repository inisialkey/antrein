import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/widgets/auth_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Step 2 of password reset: submit the emailed token + a new password.
/// [initialToken] pre-fills when the screen is opened from a reset deep link.
class ResetPasswordForm extends StatefulWidget {
  const ResetPasswordForm({
    required this.isLoading,
    required this.onSubmit,
    this.initialToken,
    super.key,
  });

  final bool isLoading;
  final void Function(String token, String newPassword) onSubmit;
  final String? initialToken;

  @override
  State<ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<ResetPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _token = TextEditingController(
    text: widget.initialToken,
  );
  final _password = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(_token.text.trim(), _password.text);
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
          children: [
            AuthHeader(subtitle: l10n.resetPasswordSubtitle),
            const Gap(Dimens.space24),
            AppTextField(
              label: l10n.resetToken,
              controller: _token,
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.tokenRequired
                  : null,
            ),
            const Gap(Dimens.space12),
            AppTextField(
              label: l10n.newPassword,
              controller: _password,
              obscureText: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                final password = value ?? '';
                if (password.isEmpty) return l10n.passwordRequired;
                if (password.length < 8) return l10n.passwordTooShort;
                return null;
              },
            ),
            const Gap(Dimens.space24),
            AppButton(
              label: l10n.resetPasswordAction,
              loading: widget.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
