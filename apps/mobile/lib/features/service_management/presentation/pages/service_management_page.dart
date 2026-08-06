import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/domain/money.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/service_management/domain/entities/managed_service.dart';
import 'package:antrein/features/service_management/presentation/cubit/service_management_cubit.dart';
import 'package:antrein/features/service_management/presentation/widgets/service_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Service catalog management (api-contract §47–§49, ui-feature-spec §35).
/// Editing needs `service.manage`; without it the page is read-only.
class ServiceManagementPage extends StatelessWidget {
  const ServiceManagementPage({
    required this.businessId,
    required this.canManage,
    super.key,
  });

  final String businessId;
  final bool canManage;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<ServiceManagementCubit>();
      unawaited(cubit.load(businessId));
      return cubit;
    },
    child: _ServiceManagementView(canManage: canManage),
  );
}

class _ServiceManagementView extends StatelessWidget {
  const _ServiceManagementView({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.servicesTitle)),
      floatingActionButton: canManage
          ? Builder(
              builder: (context) => FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: Text(l10n.serviceAdd),
                onPressed: () => openServiceFormSheet(context),
              ),
            )
          : null,
      body: BlocConsumer<ServiceManagementCubit, ServiceManagementState>(
        listenWhen: (previous, current) =>
            current.message != null && previous.message != current.message,
        listener: (context, state) => context.showSnackBar(state.message!),
        builder: (context, state) => switch (state.status) {
          ServiceListStatus.initial ||
          ServiceListStatus.loading => const AppLoading(),
          ServiceListStatus.failure => AppEmpty(
            message: state.message ?? l10n.servicesLoadFailed,
            icon: Icons.error_outline,
          ),
          ServiceListStatus.empty ||
          ServiceListStatus.success => RefreshIndicator(
            onRefresh: context.read<ServiceManagementCubit>().refresh,
            child: state.services.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: Dimens.space32.h),
                      AppEmpty(
                        message: l10n.servicesEmpty,
                        icon: Icons.design_services_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(Dimens.space16.r),
                    itemCount: state.services.length,
                    separatorBuilder: (_, _) => const Gap(Dimens.space8),
                    itemBuilder: (_, index) => _ServiceCard(
                      service: state.services[index],
                      canManage: canManage,
                      busy: state.actingServiceId != null,
                    ),
                  ),
          ),
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.canManage,
    required this.busy,
  });

  final ManagedService service;
  final bool canManage;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meta = [
      l10n.serviceMeta('${service.durationMinutes}', service.price.formatted),
      if (service.depositValue > 0)
        l10n.serviceDepositMeta(Money(service.depositValue).formatted),
      if (service.eligibleStaffIds.isEmpty)
        l10n.serviceStaffAll
      else
        l10n.serviceStaffCount(service.eligibleStaffIds.length),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Row(
          children: [
            Flexible(child: Text(service.name)),
            const Gap(Dimens.space8),
            if (!service.isActive)
              Chip(
                label: Text(l10n.serviceInactive),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Text(meta),
        trailing: canManage
            ? PopupMenuButton<_ServiceAction>(
                enabled: !busy,
                onSelected: (action) => _run(context, action),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _ServiceAction.edit,
                    child: Text(l10n.serviceEdit),
                  ),
                  if (service.isActive)
                    PopupMenuItem(
                      value: _ServiceAction.deactivate,
                      child: Text(l10n.serviceDeactivate),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  void _run(BuildContext context, _ServiceAction action) {
    switch (action) {
      case _ServiceAction.edit:
        openServiceFormSheet(context, service: service);
      case _ServiceAction.deactivate:
        unawaited(_confirmDeactivate(context));
    }
  }

  Future<void> _confirmDeactivate(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ServiceManagementCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.serviceDeactivate),
        content: Text(l10n.serviceDeactivateBody(service.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.serviceDeactivate),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.deactivate(service.id);
  }
}

enum _ServiceAction { edit, deactivate }
