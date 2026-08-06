import 'package:equatable/equatable.dart';

/// Weekday keys as the backend spells them (api-contract §54–§58.1). Monday
/// first, matching the response order.
const List<String> weekdayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// A local `HH:mm` range inside one day; the outlet timezone gives it meaning.
class TimePeriod extends Equatable {
  const TimePeriod({required this.start, required this.end});

  final String start;
  final String end;

  TimePeriod copyWith({String? start, String? end}) =>
      TimePeriod(start: start ?? this.start, end: end ?? this.end);

  @override
  List<Object?> get props => [start, end];
}

/// One outlet day (§54). `isClosed` and an empty [periods] mean the same thing
/// to the backend; the editor keeps them in step.
class OperatingDay extends Equatable {
  const OperatingDay({
    required this.dayOfWeek,
    required this.isClosed,
    this.periods = const [],
  });

  final String dayOfWeek;
  final bool isClosed;
  final List<TimePeriod> periods;

  OperatingDay copyWith({bool? isClosed, List<TimePeriod>? periods}) =>
      OperatingDay(
        dayOfWeek: dayOfWeek,
        isClosed: isClosed ?? this.isClosed,
        periods: periods ?? this.periods,
      );

  @override
  List<Object?> get props => [dayOfWeek, isClosed, periods];
}

class OperatingHours extends Equatable {
  const OperatingHours({required this.timezone, required this.days});

  final String timezone;
  final List<OperatingDay> days;

  @override
  List<Object?> get props => [timezone, days];
}

/// One staff day (§58). Breaks must sit inside a period — the backend rejects
/// a stray break with `SCHEDULE_INVALID_PERIOD`.
class StaffDay extends Equatable {
  const StaffDay({
    required this.dayOfWeek,
    required this.isAvailable,
    this.periods = const [],
    this.breaks = const [],
  });

  final String dayOfWeek;
  final bool isAvailable;
  final List<TimePeriod> periods;
  final List<TimePeriod> breaks;

  StaffDay copyWith({
    bool? isAvailable,
    List<TimePeriod>? periods,
    List<TimePeriod>? breaks,
  }) => StaffDay(
    dayOfWeek: dayOfWeek,
    isAvailable: isAvailable ?? this.isAvailable,
    periods: periods ?? this.periods,
    breaks: breaks ?? this.breaks,
  );

  @override
  List<Object?> get props => [dayOfWeek, isAvailable, periods, breaks];
}

class StaffSchedule extends Equatable {
  const StaffSchedule({
    required this.staffId,
    required this.timezone,
    required this.days,
  });

  final String staffId;
  final String timezone;
  final List<StaffDay> days;

  @override
  List<Object?> get props => [staffId, timezone, days];
}

/// A one-off outlet closure (§56, §57). There is no delete endpoint in v1.
class ClosedDate extends Equatable {
  const ClosedDate({required this.id, required this.date, this.reason});

  final String id;

  /// `YYYY-MM-DD` in the outlet timezone.
  final String date;
  final String? reason;

  @override
  List<Object?> get props => [id, date, reason];
}
