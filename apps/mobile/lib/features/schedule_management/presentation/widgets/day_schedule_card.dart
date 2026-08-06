import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/schedule_management/domain/entities/weekly_schedule.dart';
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// `HH:mm` ↔ [TimeOfDay]. The backend speaks local wall-clock time in the
/// outlet timezone, so no date or offset is involved.
TimeOfDay parseHhMm(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 0,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String formatHhMm(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// Localized weekday name for a backend day key.
String weekdayLabel(AppLocalizations l10n, String key) => switch (key) {
  'monday' => l10n.dayMonday,
  'tuesday' => l10n.dayTuesday,
  'wednesday' => l10n.dayWednesday,
  'thursday' => l10n.dayThursday,
  'friday' => l10n.dayFriday,
  'saturday' => l10n.daySaturday,
  _ => l10n.daySunday,
};

/// One editable day. Shared by the outlet-hours and staff-schedule tabs — they
/// differ only in wording and whether breaks are offered.
class DayScheduleCard extends StatelessWidget {
  const DayScheduleCard({
    required this.dayKey,
    required this.enabled,
    required this.enabledLabel,
    required this.periods,
    required this.onPeriodsChanged,
    this.onEnabledChanged,
    this.breaks,
    this.onBreaksChanged,
    super.key,
  });

  final String dayKey;
  final bool enabled;
  final String enabledLabel;

  /// Null for a member who may read the week but not save it — every control
  /// then renders disabled rather than collecting edits that go nowhere.
  final ValueChanged<bool>? onEnabledChanged;
  final List<TimePeriod> periods;
  final ValueChanged<List<TimePeriod>> onPeriodsChanged;

  /// Null hides the breaks section (outlet hours have none).
  final List<TimePeriod>? breaks;
  final ValueChanged<List<TimePeriod>>? onBreaksChanged;

  static const TimePeriod _defaultPeriod = TimePeriod(
    start: '09:00',
    end: '17:00',
  );
  static const TimePeriod _defaultBreak = TimePeriod(
    start: '12:00',
    end: '13:00',
  );

  /// The day toggle and the period controls are gated together — a member who
  /// cannot flip the day cannot edit its hours either.
  bool get editable => onEnabledChanged != null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onBreaksChanged = this.onBreaksChanged;
    final breaks = this.breaks;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    weekdayLabel(l10n, dayKey),
                    style: context.textTheme.titleSmall,
                  ),
                ),
                Text(
                  enabled ? enabledLabel : l10n.scheduleDayOff,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                Switch(value: enabled, onChanged: onEnabledChanged),
              ],
            ),
            if (enabled) ...[
              for (var index = 0; index < periods.length; index++)
                _PeriodRow(
                  period: periods[index],
                  onChanged: editable
                      ? (period) =>
                            onPeriodsChanged(_replaced(periods, index, period))
                      : null,
                  onRemove: editable
                      ? () => onPeriodsChanged(_removed(periods, index))
                      : null,
                ),
              if (editable)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.scheduleAddPeriod),
                    onPressed: () =>
                        onPeriodsChanged([...periods, _defaultPeriod]),
                  ),
                ),
              if (breaks != null && onBreaksChanged != null) ...[
                Text(l10n.scheduleBreaks, style: context.textTheme.labelLarge),
                for (var index = 0; index < breaks.length; index++)
                  _PeriodRow(
                    period: breaks[index],
                    onChanged: editable
                        ? (period) =>
                              onBreaksChanged(_replaced(breaks, index, period))
                        : null,
                    onRemove: editable
                        ? () => onBreaksChanged(_removed(breaks, index))
                        : null,
                  ),
                if (editable)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l10n.scheduleAddBreak),
                      onPressed: () =>
                          onBreaksChanged([...breaks, _defaultBreak]),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static List<TimePeriod> _replaced(
    List<TimePeriod> source,
    int index,
    TimePeriod value,
  ) => [...source]..[index] = value;

  static List<TimePeriod> _removed(List<TimePeriod> source, int index) =>
      [...source]..removeAt(index);
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.period,
    required this.onChanged,
    required this.onRemove,
  });

  final TimePeriod period;

  /// Null renders the row read-only.
  final ValueChanged<TimePeriod>? onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Row(
      children: [
        _TimeButton(
          value: period.start,
          onPicked: onChanged == null
              ? null
              : (value) => onChanged(period.copyWith(start: value)),
        ),
        const Gap(Dimens.space8),
        const Text('–'),
        const Gap(Dimens.space8),
        _TimeButton(
          value: period.end,
          onPicked: onChanged == null
              ? null
              : (value) => onChanged(period.copyWith(end: value)),
        ),
        const Spacer(),
        if (onRemove != null)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.scheduleRemovePeriod,
            onPressed: onRemove,
          ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.value, required this.onPicked});

  final String value;
  final ValueChanged<String>? onPicked;

  @override
  Widget build(BuildContext context) {
    final onPicked = this.onPicked;
    return OutlinedButton(
      onPressed: onPicked == null
          ? null
          : () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: parseHhMm(value),
              );
              if (picked != null) onPicked(formatHhMm(picked));
            },
      child: Text(value),
    );
  }
}
