import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/widgets/auth_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Step 1 of password reset: request a reset email.
class ForgotPasswordForm extends StatefulWidget {
  const ForgotPasswordForm({
    required this.isLoading,
    required this.onSubmit,
    super.key,
  });

  final bool isLoading;
  final void Function(String email) onSubmit;

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(_email.text.trim());
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
            AuthHeader(subtitle: l10n.forgotPasswordSubtitle),
            const Gap(Dimens.space24),
            AppTextField(
              label: l10n.email,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return l10n.emailRequired;
                if (!email.contains('@')) return l10n.emailInvalid;
                return null;
              },
            ),
            const Gap(Dimens.space24),
            AppButton(
              label: l10n.sendResetLink,
              loading: widget.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
