import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board_entry.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_command.dart';
import 'package:antrein/features/business_queue/presentation/cubit/staff_queue_cubit.dart';
import 'package:antrein/features/customer_queue/customer_queue.dart'
    show QueueStatus;
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Staff queue board (contract §67, §82–§90). Resolves the outlet and hosts the
/// live board; command buttons and the walk-in FAB appear only when [canManage]
/// (`queue.manage`), drag-reorder only when [canReorder] (`queue.reorder`).
class StaffQueuePage extends StatelessWidget {
  const StaffQueuePage({
    required this.businessId,
    required this.membershipOutletIds,
    required this.canManage,
    required this.canReorder,
    this.canViewBookings = false,
    this.canViewReports = false,
    this.businessName,
    super.key,
  });

  final String businessId;
  final List<String> membershipOutletIds;
  final bool canManage;
  final bool canReorder;
  final bool canViewBookings;
  final bool canViewReports;
  final String? businessName;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<StaffQueueCubit>();
      unawaited(
        cubit.load(
          businessId: businessId,
          membershipOutletIds: membershipOutletIds,
        ),
      );
      return cubit;
    },
    child: _StaffQueueView(
      businessId: businessId,
      canManage: canManage,
      canReorder: canReorder,
      canViewBookings: canViewBookings,
      canViewReports: canViewReports,
      businessName: businessName,
    ),
  );
}

class _StaffQueueView extends StatelessWidget {
  const _StaffQueueView({
    required this.businessId,
    required this.canManage,
    required this.canReorder,
    required this.canViewBookings,
    required this.canViewReports,
    this.businessName,
  });

  final String businessId;
  final bool canManage;
  final bool canReorder;
  final bool canViewBookings;
  final bool canViewReports;
  final String? businessName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(
        title: Text(businessName ?? l10n.queueTitle),
        actions: [
          Builder(
            builder: (context) {
              // Needs the resolved outlet, so it appears with the board.
              final outletId = context.select<StaffQueueCubit, String?>(
                (cubit) => cubit.state.board?.outletId,
              );
              return outletId == null
                  ? const SizedBox.shrink()
                  : _ManageMenu(businessId: businessId, outletId: outletId);
            },
          ),
          if (canViewBookings || canViewReports)
            Builder(
              builder: (context) {
                // Both routes need the resolved outlet — enabled with the board.
                final outletId = context.select<StaffQueueCubit, String?>(
                  (cubit) => cubit.state.board?.outletId,
                );
                void open(Routes route) => unawaited(
                  context.pushNamed(
                    route.name,
                    pathParameters: {
                      'businessId': businessId,
                      'outletId': outletId!,
                    },
                  ),
                );
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canViewBookings)
                      IconButton(
                        icon: const Icon(Icons.receipt_long_outlined),
                        tooltip: l10n.deskTitle,
                        onPressed: outletId == null
                            ? null
                            : () => open(Routes.businessBookings),
                      ),
                    if (canViewReports)
                      IconButton(
                        icon: const Icon(Icons.insert_chart_outlined),
                        tooltip: l10n.reportsOpen,
                        onPressed: outletId == null
                            ? null
                            : () => open(Routes.businessReports),
                      ),
                  ],
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.queueRefresh,
            onPressed: () => context.read<StaffQueueCubit>().refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.signOut,
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? Builder(
              builder: (context) => FloatingActionButton.extended(
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(l10n.walkInAdd),
                onPressed: () => _openWalkInSheet(context),
              ),
            )
          : null,
      body: BlocConsumer<StaffQueueCubit, StaffQueueState>(
        listenWhen: (previous, current) =>
            (current.actionError != null &&
                previous.actionError != current.actionError) ||
            (current.walkInCreatedNumber != null &&
                previous.walkInCreatedNumber != current.walkInCreatedNumber),
        listener: (context, state) {
          final created = state.walkInCreatedNumber;
          final message = created != null && state.actionError == null
              ? l10n.walkInCreated(created)
              : state.actionConflict
              ? l10n.boardVersionConflict
              : (state.actionError ?? l10n.boardActionFailed);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) => switch (state.status) {
          BoardStatus.initial || BoardStatus.loading => const AppLoading(),
          BoardStatus.failure => AppEmpty(
            message: state.message ?? l10n.boardLoadFailed,
            icon: Icons.error_outline,
          ),
          BoardStatus.success => RefreshIndicator(
            onRefresh: context.read<StaffQueueCubit>().refresh,
            child: _Board(
              board: state.board!,
              canManage: canManage,
              canReorder: canReorder,
              actingEntryId: state.actingEntryId,
            ),
          ),
        },
      ),
    );
  }

  void _openWalkInSheet(BuildContext context) {
    final cubit = context.read<StaffQueueCubit>();
    unawaited(cubit.loadWalkInServices());
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            BlocProvider.value(value: cubit, child: const _WalkInSheet()),
      ),
    );
  }
}

/// Entry point to the management screens (contract §43–§58.1). An entry shows
/// when the membership can read or manage that area, so a barber sees no menu
/// at all and a manager sees the screens read-only.
class _ManageMenu extends StatelessWidget {
  const _ManageMenu({required this.businessId, required this.outletId});

  final String businessId;
  final String outletId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = context.watch<AuthCubit>().state;
    final membership = authState is AuthAuthenticated
        ? authState.user.primaryMembership
        : null;
    if (membership == null) return const SizedBox.shrink();

    bool canOpen(List<String> permissions) => permissions.any(membership.can);

    final entries = <(Routes, String, bool)>[
      (
        Routes.businessServices,
        l10n.servicesTitle,
        canOpen(['service.read', 'service.manage']),
      ),
      (
        Routes.businessStaff,
        l10n.staffTitle,
        canOpen(['staff.read', 'staff.manage']),
      ),
      (
        Routes.businessSchedule,
        l10n.scheduleTitle,
        canOpen([
          'schedule.read',
          'schedule.manage',
          'staff.manage',
          'business.manage',
        ]),
      ),
      (
        Routes.businessSettings,
        l10n.settingsTitle,
        canOpen(['business.read', 'business.manage']),
      ),
    ].where((entry) => entry.$3).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<Routes>(
      icon: const Icon(Icons.tune),
      tooltip: l10n.manageMenu,
      onSelected: (route) => unawaited(
        context.pushNamed(
          route.name,
          pathParameters: {
            'businessId': businessId,
            // The service catalog is business-scoped, and go_router rejects a
            // parameter its path has no slot for.
            if (route != Routes.businessServices) 'outletId': outletId,
          },
        ),
      ),
      itemBuilder: (_) => [
        for (final entry in entries)
          PopupMenuItem(value: entry.$1, child: Text(entry.$2)),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.board,
    required this.canManage,
    required this.canReorder,
    required this.actingEntryId,
  });

  final QueueBoard board;
  final bool canManage;
  final bool canReorder;
  final String? actingEntryId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final serving = board.currentServing;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(Dimens.space16.r),
      children: [
        if (!board.isOpen) ...[
          const _ClosedBanner(),
          const Gap(Dimens.space16),
        ],
        if (board.isEmpty)
          const _EmptyState()
        else ...[
          if (serving != null) ...[
            _SectionHeader(l10n.boardNowServing),
            const Gap(Dimens.space8),
            _EntryCard(
              entry: serving,
              canManage: canManage,
              acting: actingEntryId == serving.queueEntryId,
              actionsLocked: actingEntryId != null,
              prominent: true,
            ),
            const Gap(Dimens.space16),
          ],
          _SectionHeader(l10n.boardWaitingCount(board.waiting.length)),
          const Gap(Dimens.space8),
          if (canReorder && board.waiting.length > 1)
            _ReorderableWaiting(
              waiting: board.waiting,
              canManage: canManage,
              actingEntryId: actingEntryId,
            )
          else
            for (final entry in board.waiting) ...[
              _EntryCard(
                entry: entry,
                canManage: canManage,
                acting: actingEntryId == entry.queueEntryId,
                actionsLocked: actingEntryId != null,
              ),
              const Gap(Dimens.space8),
            ],
          if (board.waiting.isEmpty)
            Text(
              l10n.boardNoneWaiting,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          if (board.skipped.isNotEmpty) ...[
            const Gap(Dimens.space16),
            _SectionHeader(l10n.boardSkippedCount(board.skipped.length)),
            const Gap(Dimens.space8),
            for (final entry in board.skipped) ...[
              _EntryCard(
                entry: entry,
                canManage: canManage,
                acting: actingEntryId == entry.queueEntryId,
                actionsLocked: actingEntryId != null,
              ),
              const Gap(Dimens.space8),
            ],
          ],
        ],
      ],
    );
  }
}

/// Long-press-and-drag reorder of the waiting list (§90, needs `queue.reorder`).
/// A drop previews the order locally, then a required-reason dialog commits it;
/// cancel restores the server order.
class _ReorderableWaiting extends StatelessWidget {
  const _ReorderableWaiting({
    required this.waiting,
    required this.canManage,
    required this.actingEntryId,
  });

  final List<QueueBoardEntry> waiting;
  final bool canManage;
  final String? actingEntryId;

  @override
  Widget build(BuildContext context) => ReorderableListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    buildDefaultDragHandles: false,
    itemCount: waiting.length,
    // onReorderItem already reports remove-then-insert indices.
    onReorderItem: (oldIndex, newIndex) =>
        unawaited(_onReorder(context, oldIndex, newIndex)),
    itemBuilder: (context, index) {
      final entry = waiting[index];
      return Padding(
        key: ValueKey(entry.queueEntryId),
        padding: EdgeInsets.only(bottom: Dimens.space8.r),
        child: ReorderableDelayedDragStartListener(
          index: index,
          enabled: actingEntryId == null,
          child: _EntryCard(
            entry: entry,
            canManage: canManage,
            acting: actingEntryId == entry.queueEntryId,
            actionsLocked: actingEntryId != null,
          ),
        ),
      );
    },
  );

  Future<void> _onReorder(
    BuildContext context,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;
    final cubit = context.read<StaffQueueCubit>()
      ..moveWaiting(oldIndex, newIndex);
    final l10n = context.l10n;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reorderReasonTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          decoration: InputDecoration(hintText: l10n.reorderReasonHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.reorderSave),
          ),
        ],
      ),
    );
    controller.dispose();
    // The reason is mandatory (§90) — an empty one cancels the move.
    if (reason == null || reason.isEmpty) {
      await cubit.cancelReorder();
    } else {
      await cubit.commitReorder(reason);
    }
  }
}

/// Walk-in creation form (§67): customer name, optional phone, service pick.
/// Staff assignment stays `any_available` — a barber is chosen at start-service.
class _WalkInSheet extends StatefulWidget {
  const _WalkInSheet();

  @override
  State<_WalkInSheet> createState() => _WalkInSheetState();
}

class _WalkInSheetState extends State<_WalkInSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _serviceId;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: Dimens.space16.r,
        right: Dimens.space16.r,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Dimens.space16.r,
      ),
      child: BlocBuilder<StaffQueueCubit, StaffQueueState>(
        builder: (context, state) {
          final services = state.walkInServices;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.walkInTitle, style: context.textTheme.titleLarge),
              const Gap(Dimens.space16),
              AppTextField(
                label: l10n.walkInNameLabel,
                controller: _name,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const Gap(Dimens.space12),
              AppTextField(
                label: l10n.walkInPhoneLabel,
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
              ),
              const Gap(Dimens.space12),
              if (state.isLoadingServices)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Dimens.space12),
                  child: LinearProgressIndicator(),
                )
              else if (services == null)
                Text(
                  l10n.walkInServicesFailed,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.error,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _serviceId,
                  decoration: InputDecoration(
                    labelText: l10n.walkInServiceLabel,
                  ),
                  items: [
                    for (final service in services)
                      DropdownMenuItem(
                        value: service.id,
                        child: Text(
                          '${service.name} · ${service.price.formatted}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _serviceId = value),
                ),
              const Gap(Dimens.space16),
              FilledButton(
                onPressed:
                    _name.text.trim().isEmpty ||
                        _serviceId == null ||
                        state.isCreatingWalkIn
                    ? null
                    : () => unawaited(_submit(context)),
                child: state.isCreatingWalkIn
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.walkInSubmit),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<StaffQueueCubit>();
    final phone = _phone.text.trim();
    await cubit.createWalkIn(
      customerName: _name.text.trim(),
      serviceId: _serviceId!,
      phoneNumber: phone.isEmpty ? null : phone,
    );
    // The page-level listener shows the created/error snackbar; the sheet only
    // closes itself on success.
    if (context.mounted && cubit.state.walkInCreatedNumber != null) {
      Navigator.pop(context);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: context.textTheme.labelMedium?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.canManage,
    required this.acting,
    required this.actionsLocked,
    this.prominent = false,
  });

  final QueueBoardEntry entry;
  final bool canManage;

  /// A command is in flight for this entry.
  final bool acting;

  /// A command is in flight somewhere on the board — lock every entry's actions.
  final bool actionsLocked;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      elevation: prominent ? 2 : 0,
      color: prominent ? context.colorScheme.primaryContainer : null,
      child: Padding(
        padding: EdgeInsets.all(Dimens.space16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  entry.displayNumber,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                _StatusChip(status: entry.status),
              ],
            ),
            const Gap(Dimens.space8),
            Text(
              entry.customerName ?? l10n.boardGuest,
              style: context.textTheme.titleMedium,
            ),
            Text(
              _subtitle(l10n),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            if (canManage) ...[
              const Gap(Dimens.space12),
              if (acting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(Dimens.space8),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                _Actions(entry: entry, locked: actionsLocked),
            ],
          ],
        ),
      ),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    final service = entry.serviceName ?? '—';
    final staff = entry.staffName ?? l10n.boardUnassigned;
    return '$service · $staff';
  }
}

/// Status-appropriate command buttons (contract §83–§89). The primary action is
/// filled; secondary actions are outlined. All disabled while [locked].
class _Actions extends StatelessWidget {
  const _Actions({required this.entry, required this.locked});

  final QueueBoardEntry entry;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final buttons = switch (entry.status) {
      QueueStatus.waiting => [(l10n.cmdCall, QueueCommand.call, true)],
      QueueStatus.called => [
        (l10n.cmdStart, QueueCommand.startService, true),
        (l10n.cmdRecall, QueueCommand.recall, false),
        (l10n.cmdSkip, QueueCommand.skip, false),
        (l10n.cmdNoShow, QueueCommand.noShow, false),
      ],
      QueueStatus.inService => [
        (l10n.cmdComplete, QueueCommand.complete, true),
      ],
      QueueStatus.skipped => [
        (l10n.cmdReturn, QueueCommand.returnToWaiting, true),
        (l10n.cmdNoShow, QueueCommand.noShow, false),
      ],
      _ => const <(String, QueueCommand, bool)>[],
    };
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: Dimens.space8.r,
      runSpacing: Dimens.space8.r,
      children: [
        for (final (label, command, primary) in buttons)
          _CommandButton(
            label: label,
            primary: primary,
            // ponytail: skip/no-show send no reason — the field is optional
            // (§85/§89). Add a reason prompt if staff need to record one.
            onPressed: locked ? null : () => _run(context, command),
          ),
      ],
    );
  }

  /// Start-service (§87) needs a staffId, and a walk-in entry has none — it
  /// joined as any-available — so the barber is picked here instead of letting
  /// the backend reject the command with `STAFF_NOT_AVAILABLE`.
  void _run(BuildContext context, QueueCommand command) {
    final cubit = context.read<StaffQueueCubit>();
    if (command == QueueCommand.startService && entry.staffId == null) {
      unawaited(cubit.loadStaffOptions());
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: _StartSheet(entry: entry),
          ),
        ),
      );
      return;
    }
    unawaited(cubit.runCommand(entry, command));
  }
}

/// Barber picker for an unassigned entry; tapping a barber starts the service.
class _StartSheet extends StatelessWidget {
  const _StartSheet({required this.entry});

  final QueueBoardEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<StaffQueueCubit, StaffQueueState>(
      builder: (context, state) {
        final staff = state.staffOptions;
        // The §82 snapshot exposes a single serving slot, so this under-reports
        // rather than guesses: an unlisted busy barber still fails server-side
        // on the one-in-service-per-staff index, with an accurate message.
        final serving = state.board?.currentServing;
        final busyStaffId = serving?.status == QueueStatus.inService
            ? serving?.staffId
            : null;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Dimens.space16.r),
                child: Text(
                  l10n.startStaffTitle,
                  style: context.textTheme.titleLarge,
                ),
              ),
              const Gap(Dimens.space12),
              if (state.isLoadingStaff)
                const Padding(
                  padding: EdgeInsets.all(Dimens.space16),
                  child: LinearProgressIndicator(),
                )
              else if (staff == null || staff.isEmpty)
                Padding(
                  padding: EdgeInsets.all(Dimens.space16.r),
                  child: Text(
                    l10n.startStaffFailed,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.error,
                    ),
                  ),
                )
              else
                for (final member in staff)
                  ListTile(
                    title: Text(member.name),
                    subtitle: member.id == busyStaffId
                        ? Text(l10n.startStaffBusy)
                        : null,
                    enabled: member.id != busyStaffId,
                    onTap: () {
                      final cubit = context.read<StaffQueueCubit>();
                      Navigator.pop(context);
                      unawaited(
                        cubit.runCommand(
                          entry,
                          QueueCommand.startService,
                          staffId: member.id,
                        ),
                      );
                    },
                  ),
              const Gap(Dimens.space8),
            ],
          ),
        );
      },
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    required this.label,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => primary
      ? FilledButton(onPressed: onPressed, child: Text(label))
      : OutlinedButton(onPressed: onPressed, child: Text(label));
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final QueueStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      QueueStatus.called || QueueStatus.inService => context.appColors.success,
      QueueStatus.skipped => context.appColors.warning,
      QueueStatus.cancelled || QueueStatus.noShow => context.colorScheme.error,
      QueueStatus.completed ||
      QueueStatus.unknown => context.colorScheme.onSurfaceVariant,
      QueueStatus.waiting => context.colorScheme.primary,
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Dimens.space8.r,
        vertical: Dimens.space4.r,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimens.radiusXl.r),
      ),
      child: Text(
        _label(context.l10n),
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n) => switch (status) {
    QueueStatus.waiting => l10n.queueStatusWaiting,
    QueueStatus.called => l10n.queueStatusCalled,
    QueueStatus.skipped => l10n.queueStatusSkipped,
    QueueStatus.inService => l10n.queueStatusInService,
    QueueStatus.completed => l10n.queueStatusCompleted,
    QueueStatus.cancelled => l10n.queueStatusCancelled,
    QueueStatus.noShow => l10n.queueStatusNoShow,
    QueueStatus.unknown => l10n.queueStatusWaiting,
  };
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner();

  @override
  Widget build(BuildContext context) {
    final warning = context.appColors.warning;
    return Container(
      padding: EdgeInsets.all(Dimens.space12.r),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimens.radiusLg.r),
        border: Border.all(color: warning),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: warning),
          const Gap.horizontal(Dimens.space12),
          Expanded(
            child: Text(
              context.l10n.boardClosed,
              style: context.textTheme.bodyMedium?.copyWith(color: warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: Dimens.space32.r),
    child: AppEmpty(
      message: context.l10n.boardEmpty,
      icon: Icons.people_outline,
    ),
  );
}
