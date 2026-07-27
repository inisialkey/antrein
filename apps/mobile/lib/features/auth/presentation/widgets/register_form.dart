import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/widgets/auth_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Registration form. Phone is optional (matches the RegisterDto contract);
/// password must be 8–128 chars (client mirrors the server rule for fast UX).
class RegisterForm extends StatefulWidget {
  const RegisterForm({
    required this.isLoading,
    required this.onSubmit,
    required this.onSignIn,
    super.key,
  });

  final bool isLoading;
  final void Function(
    String name,
    String email,
    String? phoneNumber,
    String password,
  )
  onSubmit;
  final VoidCallback onSignIn;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final phone = _phone.text.trim();
      widget.onSubmit(
        _name.text.trim(),
        _email.text.trim(),
        phone.isEmpty ? null : phone,
        _password.text,
      );
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
            AuthHeader(subtitle: l10n.createAccountSubtitle),
            const Gap(Dimens.space24),
            AppTextField(
              label: l10n.name,
              controller: _name,
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.nameRequired
                  : null,
            ),
            const Gap(Dimens.space12),
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
              label: l10n.phoneNumberOptional,
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const Gap(Dimens.space12),
            AppTextField(
              label: l10n.password,
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
              label: l10n.createAccount,
              loading: widget.isLoading,
              onPressed: _submit,
            ),
            const Gap(Dimens.space8),
            TextButton(
              onPressed: widget.isLoading ? null : widget.onSignIn,
              child: Text(l10n.alreadyHaveAccount),
            ),
          ],
        ),
      ),
    );
  }
}
