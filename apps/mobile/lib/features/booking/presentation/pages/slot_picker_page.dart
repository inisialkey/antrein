import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/booking/domain/entities/booking_draft.dart';
import 'package:antrein/features/booking/presentation/cubit/slot_picker_cubit.dart';
import 'package:antrein/features/discovery/domain/entities/staff_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Route arguments for the slot picker (passed via go_router `extra`).
class SlotPickerArgs {
  const SlotPickerArgs({required this.draft, required this.staff});

  final BookingDraft draft;
  final List<StaffMember> staff;
}

/// Step 2 of the flow: choose barber, date and slot (api-contract §42).
class SlotPickerPage extends StatelessWidget {
  const SlotPickerPage({required this.args, super.key});

  final SlotPickerArgs args;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<SlotPickerCubit>()..init(args.draft, args.staff),
    child: const _SlotPickerView(),
  );
}

class _SlotPickerView extends StatelessWidget {
  const _SlotPickerView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.watch<SlotPickerCubit>();
    final state = cubit.state;
    final draft = cubit.draft;
    final dates = List.generate(14, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day).add(Duration(days: i));
    });

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.chooseScheduleTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              Dimens.space16.r,
              Dimens.space8.r,
              Dimens.space16.r,
              0,
            ),
            child: Text(
              '${draft.service.name} · ${draft.service.durationMinutes} '
              '${l10n.minutesShort} · ${draft.service.price.formatted}',
              style: context.textTheme.bodyMedium,
            ),
          ),
          const Gap(Dimens.space16),
          _SectionLabel(l10n.chooseStaff),
          SizedBox(
            height: 44.r,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: Dimens.space16.r),
              itemCount: state.staff.length,
              separatorBuilder: (_, _) => const Gap.horizontal(Dimens.space8),
              itemBuilder: (context, index) {
                final staff = state.staff[index];
                return ChoiceChip(
                  label: Text(staff.name),
                  selected: state.selectedStaff?.id == staff.id,
                  onSelected: (_) => cubit.selectStaff(staff),
                );
              },
            ),
          ),
          const Gap(Dimens.space16),
          _SectionLabel(l10n.chooseDate),
          SizedBox(
            height: 64.r,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: Dimens.space16.r),
              itemCount: dates.length,
              separatorBuilder: (_, _) => const Gap.horizontal(Dimens.space8),
              itemBuilder: (context, index) {
                final date = dates[index];
                final selected =
                    state.selectedDate != null &&
                    DateUtils.isSameDay(state.selectedDate, date);
                return _DateChip(
                  date: date,
                  selected: selected,
                  onTap: () => cubit.selectDate(date),
                );
              },
            ),
          ),
          const Gap(Dimens.space16),
          _SectionLabel(l10n.availableSlots),
          Expanded(
            child: switch (state.status) {
              SlotLoadStatus.initial ||
              SlotLoadStatus.loading => const AppLoading(),
              SlotLoadStatus.failure => AppEmpty(
                message: state.message ?? l10n.slotsLoadFailed,
                icon: Icons.error_outline,
              ),
              SlotLoadStatus.empty => AppEmpty(
                message: l10n.noSlotsAvailable,
                icon: Icons.event_busy_outlined,
              ),
              SlotLoadStatus.success => GridView.builder(
                padding: EdgeInsets.all(Dimens.space16.r),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: Dimens.space8.r,
                  crossAxisSpacing: Dimens.space8.r,
                  childAspectRatio: 2.2,
                ),
                itemCount: state.slots.length,
                itemBuilder: (context, index) {
                  final slot = state.slots[index];
                  final selected = state.selectedSlot == slot;
                  return _SlotChip(
                    label: DateFormat.Hm().format(slot.startsAt.toLocal()),
                    available: slot.available,
                    selected: selected,
                    onTap: () => cubit.selectSlot(slot),
                  );
                },
              ),
            },
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(Dimens.space16.r),
              child: AppButton(
                label: l10n.continueAction,
                onPressed: state.selectedSlot == null
                    ? null
                    : () => context.pushNamed(
                        Routes.bookingConfirm.name,
                        extra: cubit.buildDraft(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      Dimens.space16.r,
      0,
      Dimens.space16.r,
      Dimens.space8.r,
    ),
    child: Text(text, style: context.textTheme.titleSmall),
  );
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimens.radiusMd.r),
      child: Container(
        width: 64.r,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(Dimens.radiusMd.r),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat.E(locale).format(date),
              style: context.textTheme.bodySmall?.copyWith(
                color: selected ? scheme.onPrimary : null,
              ),
            ),
            Text(
              '${date.day}',
              style: context.textTheme.titleMedium?.copyWith(
                color: selected ? scheme.onPrimary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool available;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final background = selected
        ? scheme.primary
        : available
        ? scheme.surface
        : scheme.surfaceContainerHighest;
    final foreground = selected
        ? scheme.onPrimary
        : available
        ? scheme.onSurface
        : scheme.outline;
    return InkWell(
      onTap: available ? onTap : null,
      borderRadius: BorderRadius.circular(Dimens.radiusSm.r),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(Dimens.radiusSm.r),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: context.textTheme.bodyMedium?.copyWith(
            color: foreground,
            decoration: available ? null : TextDecoration.lineThrough,
          ),
        ),
      ),
    );
  }
}
