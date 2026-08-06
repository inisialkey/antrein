import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/staff_management/domain/entities/managed_staff.dart';
import 'package:antrein/features/staff_management/presentation/cubit/staff_management_cubit.dart';
import 'package:antrein/features/staff_management/presentation/widgets/staff_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Staff roster management (api-contract §50, §52, §53, ui-feature-spec §36).
/// Editing needs `staff.manage`; without it the page is read-only.
class StaffManagementPage extends StatelessWidget {
  const StaffManagementPage({
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
      final cubit = getIt<StaffManagementCubit>();
      unawaited(cubit.load(businessId, outletId: outletId));
      return cubit;
    },
    child: _StaffManagementView(canManage: canManage),
  );
}

class _StaffManagementView extends StatelessWidget {
  const _StaffManagementView({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.staffTitle)),
      floatingActionButton: canManage
          ? Builder(
              builder: (context) => FloatingActionButton.extended(
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(l10n.staffInvite),
                onPressed: () => openStaffFormSheet(context),
              ),
            )
          : null,
      body: BlocConsumer<StaffManagementCubit, StaffManagementState>(
        listenWhen: (previous, current) =>
            (current.message != null && previous.message != current.message) ||
            (current.invitationId != null &&
                previous.invitationId != current.invitationId),
        listener: (context, state) {
          if (state.invitationId != null) {
            unawaited(_showInvitationDialog(context, state));
            return;
          }
          context.showSnackBar(state.message!);
        },
        builder: (context, state) => switch (state.status) {
          StaffListStatus.initial ||
          StaffListStatus.loading => const AppLoading(),
          StaffListStatus.failure => AppEmpty(
            message: state.message ?? l10n.staffLoadFailed,
            icon: Icons.error_outline,
          ),
          StaffListStatus.empty || StaffListStatus.success => RefreshIndicator(
            onRefresh: context.read<StaffManagementCubit>().refresh,
            child: state.staff.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: Dimens.space32.h),
                      AppEmpty(
                        message: l10n.staffEmpty,
                        icon: Icons.groups_outlined,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(Dimens.space16.r),
                    itemCount: state.staff.length,
                    separatorBuilder: (_, _) => const Gap(Dimens.space8),
                    itemBuilder: (_, index) => _StaffCard(
                      staff: state.staff[index],
                      canManage: canManage,
                      busy: state.actingStaffId != null,
                    ),
                  ),
          ),
        },
      ),
    );
  }

  /// The invitation email is best-effort on the backend, so the id is shown
  /// here for the owner to pass on by hand.
  Future<void> _showInvitationDialog(
    BuildContext context,
    StaffManagementState state,
  ) async {
    final l10n = context.l10n;
    final cubit = context.read<StaffManagementCubit>();
    final invitationId = state.invitationId!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.staffInviteSent),
        content: Text(
          l10n.staffInviteSentBody(state.invitedEmail ?? '', invitationId),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invitationId));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.staffInviteCopyCode),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
    cubit.clearInvitation();
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.staff,
    required this.canManage,
    required this.busy,
  });

  final ManagedStaff staff;
  final bool canManage;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meta = [
      staffRoleLabel(l10n, staff),
      if (staff.eligibleServiceIds.isEmpty)
        l10n.staffServicesAll
      else
        l10n.staffServicesCount(staff.eligibleServiceIds.length),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Row(
          children: [
            Flexible(child: Text(staff.name)),
            const Gap(Dimens.space8),
            if (!staff.isActive)
              Chip(
                label: Text(l10n.staffInactive),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Text(meta),
        trailing: canManage
            ? PopupMenuButton<_StaffAction>(
                enabled: !busy,
                onSelected: (action) => _run(context, action),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _StaffAction.edit,
                    child: Text(l10n.staffEdit),
                  ),
                  if (staff.isActive)
                    PopupMenuItem(
                      value: _StaffAction.deactivate,
                      child: Text(l10n.staffDeactivate),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  void _run(BuildContext context, _StaffAction action) {
    switch (action) {
      case _StaffAction.edit:
        openStaffFormSheet(context, staff: staff);
      case _StaffAction.deactivate:
        unawaited(_confirmDeactivate(context));
    }
  }

  Future<void> _confirmDeactivate(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<StaffManagementCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.staffDeactivate),
        content: Text(l10n.staffDeactivateBody(staff.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.staffDeactivate),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.deactivate(staff.id);
  }
}

enum _StaffAction { edit, deactivate }
