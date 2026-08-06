import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/features/business_management/presentation/cubit/create_business_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Self-serve business registration (api-contract §43). Lives outside the
/// `/business/*` shell because the account asking for it has no business yet.
class CreateBusinessPage extends StatelessWidget {
  const CreateBusinessPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<CreateBusinessCubit>(),
    child: const _CreateBusinessForm(),
  );
}

class _CreateBusinessForm extends StatefulWidget {
  const _CreateBusinessForm();

  @override
  State<_CreateBusinessForm> createState() => _CreateBusinessFormState();
}

class _CreateBusinessFormState extends State<_CreateBusinessForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _outletName = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _outletName,
      _address,
      _phone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final submitting = context.watch<CreateBusinessCubit>().state;

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.createBusinessTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(Dimens.space16.r),
          children: [
            Text(
              l10n.createBusinessSubtitle,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(Dimens.space16),
            AppTextField(
              controller: _name,
              label: l10n.settingsBusinessName,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const Gap(Dimens.space12),
            AppTextField(
              controller: _description,
              label: l10n.serviceDescription,
              textInputAction: TextInputAction.next,
            ),
            const Gap(Dimens.space24),
            AppTextField(
              controller: _outletName,
              label: l10n.settingsOutletName,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const Gap(Dimens.space12),
            AppTextField(
              controller: _address,
              label: l10n.settingsOutletAddress,
              textInputAction: TextInputAction.next,
              // The backend requires at least 5 characters for an address.
              validator: (value) => (value ?? '').trim().length < 5
                  ? context.l10n.fieldRequired
                  : null,
            ),
            const Gap(Dimens.space12),
            AppTextField(
              controller: _phone,
              label: l10n.phoneNumberOptional,
              keyboardType: TextInputType.phone,
            ),
            const Gap(Dimens.space24),
            AppButton(
              label: l10n.createBusinessAction,
              loading: submitting,
              onPressed: () => unawaited(_submit()),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? context.l10n.fieldRequired : null;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final auth = context.read<AuthCubit>();
    final description = _description.text.trim();
    final phone = _phone.text.trim();

    final error = await context.read<CreateBusinessCubit>().submit(
      name: _name.text.trim(),
      outletName: _outletName.text.trim(),
      address: _address.text.trim(),
      description: description.isEmpty ? null : description,
      phoneNumber: phone.isEmpty ? null : phone,
    );
    if (!mounted) return;
    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // The owner membership is what grants business access, so `/me` has to be
    // re-read before the business shell will let the user in.
    await auth.restoreSession();
    router.goNamed(Routes.businessHome.name);
  }
}
