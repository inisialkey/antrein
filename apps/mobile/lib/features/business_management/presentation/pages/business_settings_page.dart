import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/business_management/domain/entities/managed_business.dart';
import 'package:antrein/features/business_management/presentation/cubit/business_settings_cubit.dart';
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Business profile, payment options and policies (api-contract §44–§46,
/// ui-feature-spec §38). Saving needs `business.manage`; anyone else sees the
/// current settings read-only.
class BusinessSettingsPage extends StatelessWidget {
  const BusinessSettingsPage({
    required this.businessId,
    required this.outletId,
    required this.canManage,
    super.key,
  });

  final String businessId;
  final String outletId;
  final bool canManage;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<BusinessSettingsCubit>();
      unawaited(cubit.load(businessId, outletId));
      return cubit;
    },
    child: _SettingsView(canManage: canManage),
  );
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: BlocConsumer<BusinessSettingsCubit, BusinessSettingsState>(
        listenWhen: (previous, current) =>
            (current.message != null && previous.message != current.message) ||
            previous.savedTick != current.savedTick,
        listener: (context, state) =>
            context.showSnackBar(state.message ?? l10n.settingsSaved),
        builder: (context, state) => switch (state.status) {
          SettingsStatus.initial ||
          SettingsStatus.loading => const AppLoading(),
          SettingsStatus.failure => AppEmpty(
            message: state.message ?? l10n.settingsLoadFailed,
            icon: Icons.error_outline,
          ),
          SettingsStatus.success => _SettingsForm(
            // Rebuilds the form when a save replaces the server values.
            key: ValueKey(state.savedTick),
            business: state.business!,
            outlet: state.outlet,
            canManage: canManage,
            isSaving: state.isSaving,
          ),
        },
      ),
    );
  }
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({
    required this.business,
    required this.canManage,
    required this.isSaving,
    this.outlet,
    super.key,
  });

  final ManagedBusiness business;
  final ManagedOutlet? outlet;
  final bool canManage;
  final bool isSaving;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _outletName;
  late final TextEditingController _outletPhone;
  late final TextEditingController _outletAddress;
  late final TextEditingController _leadMinutes;
  late final TextEditingController _advanceDays;
  late final TextEditingController _depositValue;
  late final TextEditingController _fullRefundMinutes;
  late final TextEditingController _partialRefundMinutes;
  late final TextEditingController _partialRefundPercent;
  late final TextEditingController _noShowRefundPercent;
  late Set<String> _paymentOptions;
  late bool _automaticConfirmation;

  @override
  void initState() {
    super.initState();
    final business = widget.business;
    final outlet = widget.outlet;
    final booking = business.bookingPolicy;
    final cancellation = business.cancellationPolicy;

    _name = TextEditingController(text: business.name);
    _description = TextEditingController(text: business.description ?? '');
    _outletName = TextEditingController(text: outlet?.name ?? '');
    _outletPhone = TextEditingController(text: outlet?.phoneNumber ?? '');
    _outletAddress = TextEditingController(text: outlet?.address ?? '');
    _leadMinutes = TextEditingController(text: '${booking.minimumLeadMinutes}');
    _advanceDays = TextEditingController(text: '${booking.maximumAdvanceDays}');
    _depositValue = TextEditingController(
      text: '${business.defaultDepositValue}',
    );
    _fullRefundMinutes = TextEditingController(
      text: '${cancellation.fullRefundBeforeMinutes}',
    );
    _partialRefundMinutes = TextEditingController(
      text: '${cancellation.partialRefundBeforeMinutes}',
    );
    _partialRefundPercent = TextEditingController(
      text: '${cancellation.partialRefundPercentage}',
    );
    _noShowRefundPercent = TextEditingController(
      text: '${cancellation.noShowRefundPercentage}',
    );
    _paymentOptions = {...business.supportedPaymentOptions};
    _automaticConfirmation = booking.automaticConfirmation;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _outletName,
      _outletPhone,
      _outletAddress,
      _leadMinutes,
      _advanceDays,
      _depositValue,
      _fullRefundMinutes,
      _partialRefundMinutes,
      _partialRefundPercent,
      _noShowRefundPercent,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = widget.canManage;

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(Dimens.space16.r),
        children: [
          _SectionTitle(l10n.settingsProfile),
          AppTextField(
            controller: _name,
            label: l10n.settingsBusinessName,
            enabled: enabled,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.fieldRequired : null,
          ),
          const Gap(Dimens.space12),
          AppTextField(
            controller: _description,
            label: l10n.serviceDescription,
            enabled: enabled,
          ),

          if (widget.outlet != null) ...[
            const Gap(Dimens.space24),
            _SectionTitle(l10n.settingsOutlet),
            AppTextField(
              controller: _outletName,
              label: l10n.settingsOutletName,
              enabled: enabled,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.fieldRequired : null,
            ),
            const Gap(Dimens.space12),
            AppTextField(
              controller: _outletPhone,
              label: l10n.phoneNumberOptional,
              enabled: enabled,
              keyboardType: TextInputType.phone,
            ),
            const Gap(Dimens.space12),
            AppTextField(
              controller: _outletAddress,
              label: l10n.settingsOutletAddress,
              enabled: enabled,
            ),
          ],

          const Gap(Dimens.space24),
          _SectionTitle(l10n.settingsPaymentOptions),
          for (final option in const [
            payAtLocationOption,
            fullPaymentOption,
            depositOption,
          ])
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_paymentLabel(l10n, option)),
              value: _paymentOptions.contains(option),
              onChanged: enabled
                  ? (selected) => setState(
                      () => selected
                          ? _paymentOptions.add(option)
                          : _paymentOptions.remove(option),
                    )
                  : null,
            ),
          if (_paymentOptions.contains(depositOption)) ...[
            const Gap(Dimens.space8),
            AppTextField(
              controller: _depositValue,
              label: l10n.settingsDepositDefault,
              enabled: enabled,
              keyboardType: TextInputType.number,
              validator: _number,
            ),
          ],

          const Gap(Dimens.space24),
          _SectionTitle(l10n.settingsBookingPolicy),
          AppTextField(
            controller: _leadMinutes,
            label: l10n.settingsLeadMinutes,
            enabled: enabled,
            keyboardType: TextInputType.number,
            validator: _number,
          ),
          const Gap(Dimens.space12),
          AppTextField(
            controller: _advanceDays,
            label: l10n.settingsAdvanceDays,
            enabled: enabled,
            keyboardType: TextInputType.number,
            validator: _number,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsAutoConfirm),
            value: _automaticConfirmation,
            onChanged: enabled
                ? (value) => setState(() => _automaticConfirmation = value)
                : null,
          ),

          const Gap(Dimens.space24),
          _SectionTitle(l10n.settingsCancellationPolicy),
          AppTextField(
            controller: _fullRefundMinutes,
            label: l10n.settingsFullRefundMinutes,
            enabled: enabled,
            keyboardType: TextInputType.number,
            validator: _number,
          ),
          const Gap(Dimens.space12),
          AppTextField(
            controller: _partialRefundMinutes,
            label: l10n.settingsPartialRefundMinutes,
            enabled: enabled,
            keyboardType: TextInputType.number,
            validator: _number,
          ),
          const Gap(Dimens.space12),
          AppTextField(
            controller: _partialRefundPercent,
            label: l10n.settingsPartialRefundPercent,
            enabled: enabled,
            keyboardType: TextInputType.number,
            validator: (value) => _percent(value, l10n),
          ),
          const Gap(Dimens.space12),
          AppTextField(
            controller: _noShowRefundPercent,
            label: l10n.settingsNoShowRefundPercent,
            enabled: enabled,
            keyboardType: TextInputType.number,
            validator: (value) => _percent(value, l10n),
          ),

          if (enabled) ...[
            const Gap(Dimens.space24),
            AppButton(
              label: l10n.commonSave,
              loading: widget.isSaving,
              onPressed: _submit,
            ),
          ],
          const Gap(Dimens.space16),
        ],
      ),
    );
  }

  // A bare identifier in a pattern binds a variable rather than matching a
  // constant, so these stay plain comparisons.
  String _paymentLabel(AppLocalizations l10n, String option) {
    if (option == payAtLocationOption) return l10n.payAtLocationOption;
    if (option == fullPaymentOption) return l10n.payFullOption;
    return l10n.settingsDepositOption;
  }

  String? _number(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    return parsed == null || parsed < 0 ? context.l10n.numberInvalid : null;
  }

  String? _percent(String? value, AppLocalizations l10n) {
    final parsed = int.tryParse((value ?? '').trim());
    return parsed == null || parsed < 0 || parsed > 100
        ? l10n.numberInvalid
        : null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final description = _description.text.trim();
    final outlet = widget.outlet;
    final phone = _outletPhone.text.trim();
    final address = _outletAddress.text.trim();

    unawaited(
      context.read<BusinessSettingsCubit>().save(
        business: ManagedBusiness(
          id: widget.business.id,
          name: _name.text.trim(),
          description: description.isEmpty ? null : description,
          supportedPaymentOptions: _paymentOptions.toList(growable: false),
          bookingPolicy: BookingPolicy(
            minimumLeadMinutes: int.parse(_leadMinutes.text.trim()),
            maximumAdvanceDays: int.parse(_advanceDays.text.trim()),
            automaticConfirmation: _automaticConfirmation,
          ),
          cancellationPolicy: CancellationPolicy(
            fullRefundBeforeMinutes: int.parse(_fullRefundMinutes.text.trim()),
            partialRefundBeforeMinutes: int.parse(
              _partialRefundMinutes.text.trim(),
            ),
            partialRefundPercentage: int.parse(
              _partialRefundPercent.text.trim(),
            ),
            noShowRefundPercentage: int.parse(
              _noShowRefundPercent.text.trim(),
            ),
          ),
          defaultDepositValue: _paymentOptions.contains(depositOption)
              ? int.parse(_depositValue.text.trim())
              : 0,
        ),
        outlet: outlet == null
            ? null
            : ManagedOutlet(
                id: outlet.id,
                name: _outletName.text.trim(),
                phoneNumber: phone.isEmpty ? null : phone,
                address: address.isEmpty ? null : address,
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: Dimens.space8.h),
    child: Text(label, style: context.textTheme.titleSmall),
  );
}
