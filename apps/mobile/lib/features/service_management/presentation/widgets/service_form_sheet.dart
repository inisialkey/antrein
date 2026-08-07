import 'dart:async';

import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/files/image_picker_field.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/service_management/domain/entities/managed_service.dart';
import 'package:antrein/features/service_management/presentation/cubit/service_management_cubit.dart';
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Opens the create/edit form over the catalog. [service] null = create (§47).
void openServiceFormSheet(BuildContext context, {ManagedService? service}) {
  final cubit = context.read<ServiceManagementCubit>();
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ServiceFormSheet(service: service),
      ),
    ),
  );
}

class _ServiceFormSheet extends StatefulWidget {
  const _ServiceFormSheet({this.service});

  final ManagedService? service;

  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _duration;
  late final TextEditingController _price;
  late final TextEditingController _deposit;
  late Set<String> _staffIds;
  late bool _isActive;
  String? _imageUrl;
  String? _imageFileId;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _name = TextEditingController(text: service?.name ?? '');
    _description = TextEditingController(text: service?.description ?? '');
    _duration = TextEditingController(
      text: service == null ? '' : '${service.durationMinutes}',
    );
    _price = TextEditingController(
      text: service == null ? '' : '${service.price.amount}',
    );
    _deposit = TextEditingController(
      text: '${service?.depositValue ?? 0}',
    );
    _staffIds = {...?service?.eligibleStaffIds};
    _isActive = service?.isActive ?? true;
    _imageUrl = service?.imageUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _duration.dispose();
    _price.dispose();
    _deposit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final staff = context.select<ServiceManagementCubit, List<StaffOption>>(
      (cubit) => cubit.state.staff,
    );
    final isSaving = context.select<ServiceManagementCubit, bool>(
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
                widget.service == null ? l10n.serviceAdd : l10n.serviceEdit,
                style: context.textTheme.titleMedium,
              ),
              const Gap(Dimens.space16),
              ImagePickerField(
                imageUrl: _imageUrl,
                onPicked: _uploadImage,
              ),
              const Gap(Dimens.space12),
              AppTextField(
                controller: _name,
                label: l10n.serviceName,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? l10n.fieldRequired : null,
              ),
              const Gap(Dimens.space12),
              AppTextField(
                controller: _description,
                label: l10n.serviceDescription,
                textInputAction: TextInputAction.next,
              ),
              const Gap(Dimens.space12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _duration,
                      label: l10n.serviceDuration,
                      keyboardType: TextInputType.number,
                      validator: (value) => _positive(value, l10n),
                    ),
                  ),
                  const Gap(Dimens.space12),
                  Expanded(
                    child: AppTextField(
                      controller: _price,
                      label: l10n.servicePrice,
                      keyboardType: TextInputType.number,
                      validator: (value) => _amount(value, l10n),
                    ),
                  ),
                ],
              ),
              const Gap(Dimens.space12),
              AppTextField(
                controller: _deposit,
                label: l10n.serviceDeposit,
                keyboardType: TextInputType.number,
                validator: (value) => _amount(value, l10n),
              ),
              if (staff.isNotEmpty) ...[
                const Gap(Dimens.space16),
                Text(
                  l10n.serviceEligibleStaff,
                  style: context.textTheme.labelLarge,
                ),
                Text(
                  l10n.serviceEligibleStaffHint,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(Dimens.space8),
                Wrap(
                  spacing: Dimens.space8.r,
                  children: [
                    for (final option in staff)
                      FilterChip(
                        label: Text(option.name),
                        selected: _staffIds.contains(option.id),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _staffIds.add(option.id)
                              : _staffIds.remove(option.id),
                        ),
                      ),
                  ],
                ),
              ],
              const Gap(Dimens.space8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.serviceActive),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const Gap(Dimens.space16),
              AppButton(
                label: l10n.commonSave,
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

  String? _positive(String? value, AppLocalizations l10n) {
    final parsed = int.tryParse((value ?? '').trim());
    return parsed == null || parsed <= 0 ? l10n.numberInvalid : null;
  }

  String? _amount(String? value, AppLocalizations l10n) {
    final parsed = int.tryParse((value ?? '').trim());
    return parsed == null || parsed < 0 ? l10n.numberInvalid : null;
  }

  /// Uploads immediately so the owner sees the photo before saving; the id is
  /// only attached when the form is submitted.
  Future<String?> _uploadImage(String path) async {
    final result = await context.read<ServiceManagementCubit>().uploadImage(
      path,
    );
    return result.match((failure) => failure.message, (image) {
      setState(() {
        _imageUrl = image.url;
        _imageFileId = image.id;
      });
      return null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.l10n.serviceSaved;
    final description = _description.text.trim();

    final error = await context.read<ServiceManagementCubit>().save(
      ServiceDraft(
        id: widget.service?.id,
        name: _name.text.trim(),
        description: description.isEmpty ? null : description,
        imageFileId: _imageFileId,
        durationMinutes: int.parse(_duration.text.trim()),
        priceAmount: int.parse(_price.text.trim()),
        depositValue: int.parse(_deposit.text.trim()),
        eligibleStaffIds: _staffIds.toList(growable: false),
        isActive: _isActive,
      ),
    );
    if (!mounted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? saved)));
    if (error == null) navigator.pop();
  }
}
