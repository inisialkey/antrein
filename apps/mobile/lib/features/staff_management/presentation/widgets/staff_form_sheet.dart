import 'dart:async';

import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/staff_management/domain/entities/managed_staff.dart';
import 'package:antrein/features/staff_management/presentation/cubit/staff_management_cubit.dart';
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Localized label for a role (api-contract §128).
String staffRoleLabel(AppLocalizations l10n, ManagedStaff staff) =>
    switch (staff.roleEnum) {
      StaffRole.manager => l10n.roleManager,
      StaffRole.barber => l10n.roleBarber,
      StaffRole.frontDesk => l10n.roleFrontDesk,
      StaffRole.cashier => l10n.roleCashier,
      // An owner (or a role this build predates) renders as the raw label.
      null => staff.role,
    };

/// Opens the invite/edit form. [staff] null = invite by email (§50).
void openStaffFormSheet(BuildContext context, {ManagedStaff? staff}) {
  final cubit = context.read<StaffManagementCubit>();
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _StaffFormSheet(staff: staff),
      ),
    ),
  );
}

class _StaffFormSheet extends StatefulWidget {
  const _StaffFormSheet({this.staff});

  final ManagedStaff? staff;

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _name;
  late StaffRole _role;
  late Set<String> _serviceIds;
  late bool _isActive;

  bool get _isInvite => widget.staff == null;

  @override
  void initState() {
    super.initState();
    final staff = widget.staff;
    _email = TextEditingController();
    _name = TextEditingController(text: staff?.name ?? '');
    _role = staff?.roleEnum ?? StaffRole.barber;
    _serviceIds = {...?staff?.eligibleServiceIds};
    _isActive = staff?.isActive ?? true;
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services = context.select<StaffManagementCubit, List<ServiceOption>>(
      (cubit) => cubit.state.services,
    );
    final isSaving = context.select<StaffManagementCubit, bool>(
      (cubit) => cubit.state.isSaving,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: Dimens.space16.r,
        right: Dimens.space16.r,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Dimens.space16.r,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isInvite ? l10n.staffInvite : l10n.staffEdit,
                style: context.textTheme.titleMedium,
              ),
              const Gap(Dimens.space16),
              if (_isInvite) ...[
                AppTextField(
                  controller: _email,
                  label: l10n.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return l10n.emailRequired;
                    return text.contains('@') ? null : l10n.emailInvalid;
                  },
                ),
                const Gap(Dimens.space12),
              ],
              AppTextField(
                controller: _name,
                label: l10n.staffDisplayName,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? l10n.fieldRequired : null,
              ),
              const Gap(Dimens.space12),
              DropdownButtonFormField<StaffRole>(
                initialValue: _role,
                decoration: InputDecoration(labelText: l10n.staffRole),
                items: [
                  for (final role in StaffRole.values)
                    DropdownMenuItem(
                      value: role,
                      child: Text(_roleLabel(l10n, role)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _role = value ?? StaffRole.barber),
              ),
              if (services.isNotEmpty) ...[
                const Gap(Dimens.space16),
                Text(
                  l10n.staffEligibleServices,
                  style: context.textTheme.labelLarge,
                ),
                Text(
                  l10n.staffEligibleServicesHint,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(Dimens.space8),
                Wrap(
                  spacing: Dimens.space8.r,
                  children: [
                    for (final option in services)
                      FilterChip(
                        label: Text(option.name),
                        selected: _serviceIds.contains(option.id),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _serviceIds.add(option.id)
                              : _serviceIds.remove(option.id),
                        ),
                      ),
                  ],
                ),
              ],
              if (!_isInvite) ...[
                const Gap(Dimens.space8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.staffActive),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
              const Gap(Dimens.space16),
              AppButton(
                label: _isInvite ? l10n.staffInviteSend : l10n.commonSave,
                loading: isSaving,
                onPressed: () => unawaited(_submit()),
              ),
              const Gap(Dimens.space8),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, StaffRole role) => switch (role) {
    StaffRole.manager => l10n.roleManager,
    StaffRole.barber => l10n.roleBarber,
    StaffRole.frontDesk => l10n.roleFrontDesk,
    StaffRole.cashier => l10n.roleCashier,
  };

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.l10n.staffSaved;

    final error = await context.read<StaffManagementCubit>().save(
      StaffDraft(
        id: widget.staff?.id,
        email: _isInvite ? _email.text.trim() : null,
        displayName: _name.text.trim(),
        role: _role,
        eligibleServiceIds: _serviceIds.toList(growable: false),
        isActive: _isActive,
      ),
    );
    if (!mounted) return;

    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    // An invite has its own dialog on the roster page; an edit just confirms.
    if (!_isInvite) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(saved)));
    }
  }
}
