import 'package:antrein/features/schedule_management/domain/entities/weekly_schedule.dart';

/// Wire ↔ domain mapping for schedules (api-contract §54–§58.1).
///
/// ponytail: plain functions instead of freezed models — the payloads are two
/// nested arrays of strings, so a generated model layer would be pure ceremony
/// over the same field names.

List<Map<String, dynamic>> _maps(Object? value) =>
    ((value as List<dynamic>?) ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

List<TimePeriod> _periods(Object? value, String startKey, String endKey) =>
    _maps(value)
        .map(
          (e) => TimePeriod(
            start: e[startKey] as String? ?? '',
            end: e[endKey] as String? ?? '',
          ),
        )
        .where((p) => p.start.isNotEmpty && p.end.isNotEmpty)
        .toList();

OperatingHours operatingHoursFromJson(Map<String, dynamic> json) {
  final byDay = {
    for (final day in _maps(json['days']))
      day['dayOfWeek'] as String? ?? '': day,
  };
  return OperatingHours(
    timezone: json['timezone'] as String? ?? 'Asia/Jakarta',
    // Always seven days in a fixed order, even if the backend omits one — the
    // editor renders a full week and PUT replaces the whole week anyway.
    days: [
      for (final key in weekdayKeys)
        OperatingDay(
          dayOfWeek: key,
          isClosed: byDay[key]?['isClosed'] as bool? ?? true,
          periods: _periods(byDay[key]?['periods'], 'opensAt', 'closesAt'),
        ),
    ],
  );
}

Map<String, dynamic> operatingHoursToJson(OperatingHours hours) => {
  'timezone': hours.timezone,
  'days': [
    for (final day in hours.days)
      {
        'dayOfWeek': day.dayOfWeek,
        'isClosed': day.isClosed,
        'periods': day.isClosed
            ? const <Map<String, String>>[]
            : [
                for (final period in day.periods)
                  {'opensAt': period.start, 'closesAt': period.end},
              ],
      },
  ],
};

StaffSchedule staffScheduleFromJson(Map<String, dynamic> json) {
  final byDay = {
    for (final day in _maps(json['days']))
      day['dayOfWeek'] as String? ?? '': day,
  };
  return StaffSchedule(
    staffId: json['staffId'] as String? ?? '',
    timezone: json['timezone'] as String? ?? 'Asia/Jakarta',
    days: [
      for (final key in weekdayKeys)
        StaffDay(
          dayOfWeek: key,
          isAvailable: byDay[key]?['isAvailable'] as bool? ?? false,
          periods: _periods(byDay[key]?['periods'], 'startsAt', 'endsAt'),
          breaks: _periods(byDay[key]?['breaks'], 'startsAt', 'endsAt'),
        ),
    ],
  );
}

Map<String, dynamic> staffScheduleToJson(StaffSchedule schedule) => {
  'timezone': schedule.timezone,
  'days': [
    for (final day in schedule.days)
      {
        'dayOfWeek': day.dayOfWeek,
        'isAvailable': day.isAvailable,
        'periods': day.isAvailable
            ? [
                for (final period in day.periods)
                  {'startsAt': period.start, 'endsAt': period.end},
              ]
            : const <Map<String, String>>[],
        // A break outside its period is rejected, and an unavailable day may
        // not carry breaks at all.
        'breaks': day.isAvailable
            ? [
                for (final period in day.breaks)
                  {'startsAt': period.start, 'endsAt': period.end},
              ]
            : const <Map<String, String>>[],
      },
  ],
};

List<ClosedDate> closedDatesFromJson(Map<String, dynamic> json) => [
  for (final item in _maps(json['items']))
    ClosedDate(
      id: item['id'] as String? ?? '',
      date: item['date'] as String? ?? '',
      reason: item['reason'] as String?,
    ),
];
