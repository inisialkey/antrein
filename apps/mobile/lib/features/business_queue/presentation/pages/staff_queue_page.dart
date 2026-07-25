import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
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

/// Staff queue board (contract §82–§89). Resolves the outlet and hosts the live
/// board; command buttons appear only when [canManage] (holds `queue.manage`).
class StaffQueuePage extends StatelessWidget {
  const StaffQueuePage({
    required this.businessId,
    required this.membershipOutletIds,
    required this.canManage,
    this.businessName,
    super.key,
  });

  final String businessId;
  final List<String> membershipOutletIds;
  final bool canManage;
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
    child: _StaffQueueView(canManage: canManage, businessName: businessName),
  );
}

class _StaffQueueView extends StatelessWidget {
  const _StaffQueueView({required this.canManage, this.businessName});

  final bool canManage;
  final String? businessName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(
        title: Text(businessName ?? l10n.queueTitle),
        actions: [
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
      body: BlocConsumer<StaffQueueCubit, StaffQueueState>(
        listenWhen: (previous, current) =>
            current.actionError != null &&
            previous.actionError != current.actionError,
        listener: (context, state) {
          final message = state.actionConflict
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
              actingEntryId: state.actingEntryId,
            ),
          ),
        },
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.board,
    required this.canManage,
    required this.actingEntryId,
  });

  final QueueBoard board;
  final bool canManage;
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
            onPressed: locked
                ? null
                // ponytail: skip/no-show send no reason — the field is optional
                // (§85/§89). Add a reason prompt if staff need to record one.
                : () => context.read<StaffQueueCubit>().runCommand(
                    entry,
                    command,
                  ),
          ),
      ],
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
