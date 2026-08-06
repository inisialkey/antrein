import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/schedule_management/domain/entities/weekly_schedule.dart';
import 'package:antrein/features/schedule_management/presentation/cubit/schedule_management_cubit.dart';
import 'package:antrein/features/schedule_management/presentation/widgets/closed_date_sheet.dart';
import 'package:antrein/features/schedule_management/presentation/widgets/day_schedule_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Outlet hours, closed dates and staff schedules (api-contract §54–§58.1,
/// ui-feature-spec §37). Reads are open to any member; saving hours and
/// closures needs `business.manage`, saving a staff week needs `staff.manage`.
class ScheduleManagementPage extends StatelessWidget {
  const ScheduleManagementPage({
    required this.businessId,
    required this.outletId,
    required this.canManageOutlet,
    required this.canManageStaff,
    super.key,
  });

  final String businessId;
  final String outletId;
  final bool canManageOutlet;
  final bool canManageStaff;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<ScheduleManagementCubit>();
      unawaited(cubit.load(businessId, outletId));
      return cubit;
    },
    child: _ScheduleView(
      canManageOutlet: canManageOutlet,
      canManageStaff: canManageStaff,
    ),
  );
}

class _ScheduleView extends StatelessWidget {
  const _ScheduleView({
    required this.canManageOutlet,
    required this.canManageStaff,
  });

  final bool canManageOutlet;
  final bool canManageStaff;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: AppScaffold(
        appBar: AppBar(
          title: Text(l10n.scheduleTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.scheduleTabHours),
              Tab(text: l10n.scheduleTabClosedDates),
              Tab(text: l10n.scheduleTabStaff),
            ],
          ),
        ),
        body: BlocConsumer<ScheduleManagementCubit, ScheduleManagementState>(
          listenWhen: (previous, current) =>
              (current.message != null &&
                  previous.message != current.message) ||
              previous.savedTick != current.savedTick,
          listener: (context, state) => context.showSnackBar(
            state.message ?? l10n.scheduleSaved,
          ),
          builder: (context, state) => switch (state.status) {
            ScheduleStatus.initial ||
            ScheduleStatus.loading => const AppLoading(),
            ScheduleStatus.failure => AppEmpty(
              message: state.message ?? l10n.scheduleLoadFailed,
              icon: Icons.error_outline,
            ),
            ScheduleStatus.success => TabBarView(
              children: [
                _HoursTab(state: state, canManage: canManageOutlet),
                _ClosedDatesTab(state: state, canManage: canManageOutlet),
                _StaffTab(state: state, canManage: canManageStaff),
              ],
            ),
          },
        ),
      ),
    );
  }
}

class _HoursTab extends StatelessWidget {
  const _HoursTab({required this.state, required this.canManage});

  final ScheduleManagementState state;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ScheduleManagementCubit>();
    return ListView(
      padding: EdgeInsets.all(Dimens.space16.r),
      children: [
        for (var index = 0; index < state.days.length; index++) ...[
          DayScheduleCard(
            dayKey: state.days[index].dayOfWeek,
            enabled: !state.days[index].isClosed,
            enabledLabel: l10n.scheduleOpen,
            onEnabledChanged: canManage
                ? (open) => cubit.setOperatingDay(
                    index,
                    state.days[index].copyWith(
                      isClosed: !open,
                      // Turning a day on with no hours yet would save as closed.
                      periods: open && state.days[index].periods.isEmpty
                          ? const [TimePeriod(start: '09:00', end: '17:00')]
                          : state.days[index].periods,
                    ),
                  )
                : null,
            periods: state.days[index].periods,
            onPeriodsChanged: (periods) => cubit.setOperatingDay(
              index,
              state.days[index].copyWith(
                periods: periods,
                isClosed: periods.isEmpty,
              ),
            ),
          ),
          const Gap(Dimens.space8),
        ],
        if (canManage) ...[
          const Gap(Dimens.space8),
          AppButton(
            label: l10n.commonSave,
            loading: state.isSavingHours,
            onPressed: () => unawaited(cubit.saveOperatingHours()),
          ),
        ],
      ],
    );
  }
}

class _ClosedDatesTab extends StatelessWidget {
  const _ClosedDatesTab({required this.state, required this.canManage});

  final ScheduleManagementState state;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: EdgeInsets.all(Dimens.space16.r),
      children: [
        if (canManage) ...[
          AppButton(
            label: l10n.closedDateAdd,
            onPressed: () => openClosedDateSheet(context),
          ),
          const Gap(Dimens.space16),
        ],
        if (state.closedDates.isEmpty)
          AppEmpty(
            message: l10n.closedDatesEmpty,
            icon: Icons.event_busy_outlined,
          )
        else
          for (final closed in state.closedDates)
            Card(
              margin: EdgeInsets.only(bottom: Dimens.space8.h),
              child: ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(closed.date),
                subtitle: closed.reason == null ? null : Text(closed.reason!),
              ),
            ),
      ],
    );
  }
}

class _StaffTab extends StatelessWidget {
  const _StaffTab({required this.state, required this.canManage});

  final ScheduleManagementState state;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ScheduleManagementCubit>();
    if (state.staff.isEmpty) {
      return AppEmpty(message: l10n.staffEmpty, icon: Icons.groups_outlined);
    }

    return ListView(
      padding: EdgeInsets.all(Dimens.space16.r),
      children: [
        DropdownButtonFormField<String>(
          initialValue: state.selectedStaffId,
          decoration: InputDecoration(labelText: l10n.scheduleStaffPicker),
          items: [
            for (final member in state.staff)
              DropdownMenuItem(value: member.id, child: Text(member.name)),
          ],
          onChanged: (value) =>
              value == null ? null : unawaited(cubit.selectStaff(value)),
        ),
        const Gap(Dimens.space16),
        if (state.isLoadingStaffSchedule)
          const AppLoading()
        else if (state.selectedStaffId == null)
          Text(
            l10n.scheduleStaffPickPrompt,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          for (var index = 0; index < state.staffDays.length; index++) ...[
            DayScheduleCard(
              dayKey: state.staffDays[index].dayOfWeek,
              enabled: state.staffDays[index].isAvailable,
              enabledLabel: l10n.scheduleAvailable,
              onEnabledChanged: canManage
                  ? (available) => cubit.setStaffDay(
                      index,
                      state.staffDays[index].copyWith(
                        isAvailable: available,
                        periods:
                            available && state.staffDays[index].periods.isEmpty
                            ? const [TimePeriod(start: '09:00', end: '17:00')]
                            : state.staffDays[index].periods,
                      ),
                    )
                  : null,
              periods: state.staffDays[index].periods,
              onPeriodsChanged: (periods) => cubit.setStaffDay(
                index,
                state.staffDays[index].copyWith(
                  periods: periods,
                  isAvailable: periods.isNotEmpty,
                ),
              ),
              breaks: state.staffDays[index].breaks,
              onBreaksChanged: (breaks) => cubit.setStaffDay(
                index,
                state.staffDays[index].copyWith(breaks: breaks),
              ),
            ),
            const Gap(Dimens.space8),
          ],
          if (canManage) ...[
            const Gap(Dimens.space8),
            AppButton(
              label: l10n.commonSave,
              loading: state.isSavingStaff,
              onPressed: () => unawaited(cubit.saveStaffSchedule()),
            ),
          ],
        ],
      ],
    );
  }
}
