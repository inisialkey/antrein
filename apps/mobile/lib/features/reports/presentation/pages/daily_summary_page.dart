import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/reports/domain/entities/daily_summary.dart';
import 'package:antrein/features/reports/presentation/cubit/daily_summary_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// Business daily summary (contract §98, ui-feature-spec §39) — simple stat
/// cards for one outlet-day, with a day switcher.
class DailySummaryPage extends StatelessWidget {
  const DailySummaryPage({
    required this.businessId,
    required this.outletId,
    super.key,
  });

  final String businessId;
  final String outletId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<DailySummaryCubit>();
      unawaited(cubit.load(businessId: businessId, outletId: outletId));
      return cubit;
    },
    child: const _DailySummaryView(),
  );
}

class _DailySummaryView extends StatelessWidget {
  const _DailySummaryView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<DailySummaryCubit, DailySummaryState>(
      builder: (context, state) => AppScaffold(
        appBar: AppBar(title: Text(l10n.reportsTitle)),
        body: switch (state.status) {
          DailySummaryStatus.initial ||
          DailySummaryStatus.loading => const AppLoading(),
          DailySummaryStatus.failure => AppEmpty(
            message: state.message ?? l10n.reportsLoadFailed,
            icon: Icons.error_outline,
          ),
          DailySummaryStatus.success => _Loaded(summary: state.summary!),
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: () =>
          context.read<DailySummaryCubit>().changeDate(summary.date),
      child: ListView(
        padding: EdgeInsets.all(Dimens.space16.r),
        children: [
          _DateRow(date: summary.date),
          const Gap(Dimens.space16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Dimens.space12.r,
            crossAxisSpacing: Dimens.space12.r,
            childAspectRatio: 1.6,
            children: [
              // ui-feature-spec §39: the eight MVP cards.
              _StatCard(
                label: l10n.reportTotalBookings,
                value: '${summary.totalBookings}',
              ),
              _StatCard(
                label: l10n.reportCompleted,
                value: '${summary.completed}',
              ),
              _StatCard(
                label: l10n.reportCancelled,
                value: '${summary.cancelled}',
              ),
              _StatCard(label: l10n.reportNoShow, value: '${summary.noShow}'),
              _StatCard(
                label: l10n.reportAvgWait,
                value: '${summary.averageWaitMinutes} ${l10n.minutesShort}',
              ),
              _StatCard(
                label: l10n.reportGrossPaid,
                value: summary.grossPaid.formatted,
              ),
              _StatCard(
                label: l10n.reportPending,
                value: summary.pendingPayments.formatted,
              ),
              _StatCard(
                label: l10n.reportRefunded,
                value: summary.refunded.formatted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date});

  /// `YYYY-MM-DD` as echoed by the backend.
  final String date;

  static String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DailySummaryCubit>();
    final locale = Localizations.localeOf(context).toString();
    final shown = DateTime.parse(date);
    // ponytail: "today" uses the device clock, not Asia/Jakarta — barbers run
    // in WIB anyway; swap to a backend-driven cap if other zones ever matter.
    final today = _fmt(DateTime.now());
    final atToday = date.compareTo(today) >= 0;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => unawaited(
            cubit.changeDate(_fmt(shown.subtract(const Duration(days: 1)))),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () => unawaited(_pickDate(context, cubit, shown)),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: Dimens.space8.r),
              child: Text(
                DateFormat('EEEE, d MMMM yyyy', locale).format(shown),
                style: context.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: atToday
              ? null
              : () => unawaited(
                  cubit.changeDate(_fmt(shown.add(const Duration(days: 1)))),
                ),
        ),
      ],
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    DailySummaryCubit cubit,
    DateTime shown,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: shown.isAfter(now) ? now : shown,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) {
      await cubit.changeDate(_fmt(picked));
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(Dimens.space12.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: context.textTheme.titleLarge),
          ),
          const Gap(Dimens.space4),
          Text(
            label,
            style: context.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}
