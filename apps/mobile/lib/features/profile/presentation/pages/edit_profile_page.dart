import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/files/image_picker_field.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/features/profile/domain/entities/notification_preferences.dart';
import 'package:antrein/features/profile/presentation/cubit/edit_profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Name, phone and avatar (api-contract §32). Prefilled from the session rather
/// than a fresh read — `/me` is what put the user in [AuthCubit] to begin with.
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    if (authState is! AuthAuthenticated) return const AppLoading();

    return BlocProvider(
      create: (_) => getIt<EditProfileCubit>(),
      child: _EditProfileForm(
        name: authState.user.name,
        phoneNumber: authState.user.phoneNumber,
        avatarUrl: authState.user.avatarUrl,
      ),
    );
  }
}

class _EditProfileForm extends StatefulWidget {
  const _EditProfileForm({
    required this.name,
    this.phoneNumber,
    this.avatarUrl,
  });

  final String name;
  final String? phoneNumber;
  final String? avatarUrl;

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  String? _avatarUrl;
  String? _avatarFileId;
  bool _clearAvatar = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _phone = TextEditingController(text: widget.phoneNumber ?? '');
    _avatarUrl = widget.avatarUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSaving = context.watch<EditProfileCubit>().state;

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.profileEditTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(Dimens.space16.r),
          children: [
            ImagePickerField(
              imageUrl: _avatarUrl,
              circular: true,
              onPicked: _uploadAvatar,
              onCleared: () => setState(() {
                _avatarUrl = null;
                _avatarFileId = null;
                _clearAvatar = true;
              }),
            ),
            const Gap(Dimens.space16),
            AppTextField(
              controller: _name,
              label: l10n.profileFullName,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.fieldRequired : null,
            ),
            const Gap(Dimens.space12),
            AppTextField(
              controller: _phone,
              label: l10n.phoneNumberOptional,
              keyboardType: TextInputType.phone,
            ),
            const Gap(Dimens.space24),
            AppButton(
              label: l10n.commonSave,
              loading: isSaving,
              onPressed: () => unawaited(_submit()),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadAvatar(String path) async {
    final result = await context.read<EditProfileCubit>().uploadAvatar(path);
    return result.match((failure) => failure.message, (image) {
      setState(() {
        _avatarUrl = image.url;
        _avatarFileId = image.id;
        _clearAvatar = false;
      });
      return null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = context.l10n;
    final auth = context.read<AuthCubit>();
    final router = GoRouter.of(context);
    final phone = _phone.text.trim();

    final error = await context.read<EditProfileCubit>().save(
      ProfileDraft(
        name: _name.text.trim(),
        phoneNumber: phone.isEmpty ? null : phone,
        avatarFileId: _avatarFileId,
        clearAvatar: _clearAvatar,
      ),
    );
    if (!mounted) return;
    if (error != null) {
      context.showSnackBar(error);
      return;
    }
    // The session holds the old name/avatar; re-read so every screen that
    // renders them updates, then leave the form.
    await auth.restoreSession();
    if (!mounted) return;
    context.showSnackBar(l10n.profileEditSaved);
    if (router.canPop()) router.pop();
  }
}
