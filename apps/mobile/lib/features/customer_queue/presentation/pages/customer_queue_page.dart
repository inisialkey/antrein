import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_status.dart';
import 'package:antrein/features/customer_queue/presentation/cubit/customer_queue_cubit.dart';
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomerQueuePage extends StatelessWidget {
  const CustomerQueuePage({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<CustomerQueueCubit>();
      unawaited(cubit.load(bookingId));
      return cubit;
    },
    child: const _CustomerQueueView(),
  );
}

class _CustomerQueueView extends StatelessWidget {
  const _CustomerQueueView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<CustomerQueueCubit, CustomerQueueState>(
      builder: (context, state) => AppScaffold(
        appBar: AppBar(
          title: Text(l10n.queueTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<CustomerQueueCubit>().refresh(),
              tooltip: l10n.queueRefresh,
            ),
          ],
        ),
        body: switch (state.status) {
          QueueLoadStatus.initial ||
          QueueLoadStatus.loading => const AppLoading(),
          QueueLoadStatus.empty => AppEmpty(
            message: l10n.queueEmpty,
            icon: Icons.confirmation_number_outlined,
          ),
          QueueLoadStatus.failure => AppEmpty(
            message: state.message ?? l10n.queueLoadFailed,
            icon: Icons.error_outline,
          ),
          QueueLoadStatus.success => RefreshIndicator(
            onRefresh: context.read<CustomerQueueCubit>().refresh,
            child: _QueueBody(entry: state.entry!),
          ),
        },
      ),
    );
  }
}

class _QueueBody extends StatelessWidget {
  const _QueueBody({required this.entry});

  final QueueEntry entry;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: EdgeInsets.all(Dimens.space16.r),
    children: [
      if (entry.isCalled) ...[
        const _CalledBanner(),
        const Gap(Dimens.space16),
      ],
      _HeroCard(entry: entry),
      const Gap(Dimens.space16),
      _PeopleAhead(count: entry.peopleAhead),
      const Gap(Dimens.space16),
      _InfoTile(
        icon: Icons.timelapse_outlined,
        label: context.l10n.queueEstimatedWait(entry.estimatedWaitMinutes),
      ),
      if (entry.currentServingNumber != null) ...[
        const Gap(Dimens.space8),
        _InfoTile(
          icon: Icons.campaign_outlined,
          label: context.l10n.queueNowServing(entry.currentServingNumber!),
        ),
      ],
    ],
  );
}

class _CalledBanner extends StatelessWidget {
  const _CalledBanner();

  @override
  Widget build(BuildContext context) {
    final success = context.appColors.success;
    return Container(
      padding: EdgeInsets.all(Dimens.space16.r),
      decoration: BoxDecoration(
        color: success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimens.radiusLg.r),
        border: Border.all(color: success),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: success),
          const Gap.horizontal(Dimens.space12),
          Expanded(
            child: Text(
              context.l10n.queueCalledBanner,
              style: context.textTheme.titleMedium?.copyWith(
                color: success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.entry});

  final QueueEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: Dimens.space32.r,
          horizontal: Dimens.space16.r,
        ),
        child: Column(
          children: [
            Text(
              l10n.queueYourNumber,
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(Dimens.space12),
            Text(
              entry.displayNumber,
              style: context.textTheme.displayLarge?.copyWith(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const Gap(Dimens.space16),
            _StatusChip(status: entry.status),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final QueueStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Dimens.space16.r,
        vertical: Dimens.space8.r,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimens.radiusXl.r),
      ),
      child: Text(
        _label(context.l10n),
        style: context.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _color(BuildContext context) => switch (status) {
    QueueStatus.called || QueueStatus.inService => context.appColors.success,
    QueueStatus.skipped => context.appColors.warning,
    QueueStatus.cancelled || QueueStatus.noShow => context.colorScheme.error,
    QueueStatus.completed ||
    QueueStatus.unknown => context.colorScheme.onSurfaceVariant,
    QueueStatus.waiting => context.colorScheme.primary,
  };

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

class _PeopleAhead extends StatelessWidget {
  const _PeopleAhead({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(Dimens.space16.r),
        child: Row(
          children: [
            Icon(
              Icons.groups_outlined,
              color: context.colorScheme.primary,
              size: Dimens.iconLg.r,
            ),
            const Gap.horizontal(Dimens.space16),
            Expanded(
              child: Text(
                count == 0 ? l10n.queueNoneAhead : l10n.queuePeopleAhead(count),
                style: context.textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: context.colorScheme.onSurfaceVariant),
      const Gap.horizontal(Dimens.space12),
      Expanded(child: Text(label, style: context.textTheme.bodyMedium)),
    ],
  );
}
