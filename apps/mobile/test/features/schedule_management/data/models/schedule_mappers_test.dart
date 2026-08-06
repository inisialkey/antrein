import 'package:antrein/features/schedule_management/data/models/schedule_mappers.dart';
import 'package:antrein/features/schedule_management/domain/entities/weekly_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('operating hours', () {
    test('fills the whole week, closing the days the server omits', () {
      final hours = operatingHoursFromJson({
        'timezone': 'Asia/Jakarta',
        'days': [
          {
            'dayOfWeek': 'monday',
            'isClosed': false,
            'periods': [
              {'opensAt': '09:00', 'closesAt': '12:00'},
              {'opensAt': '13:00', 'closesAt': '21:00'},
            ],
          },
        ],
      });

      expect(hours.days, hasLength(7));
      expect(hours.days.first.dayOfWeek, 'monday');
      expect(hours.days.first.periods, [
        const TimePeriod(start: '09:00', end: '12:00'),
        const TimePeriod(start: '13:00', end: '21:00'),
      ]);
      expect(hours.days.skip(1).every((d) => d.isClosed), isTrue);
    });

    test('a closed day is sent without periods', () {
      final json = operatingHoursToJson(
        const OperatingHours(
          timezone: 'Asia/Jakarta',
          days: [
            OperatingDay(
              dayOfWeek: 'monday',
              isClosed: true,
              // Left over from before the toggle — the backend rejects periods
              // on a closed day, so they must not be sent.
              periods: [TimePeriod(start: '09:00', end: '17:00')],
            ),
          ],
        ),
      );

      final monday = (json['days']! as List<dynamic>).single as Map;
      expect(monday['isClosed'], isTrue);
      expect(monday['periods'], isEmpty);
    });
  });

  group('staff schedule', () {
    test(
      'reads periods and breaks, defaulting missing days to unavailable',
      () {
        final schedule = staffScheduleFromJson({
          'staffId': 'stf_1',
          'timezone': 'Asia/Jakarta',
          'days': [
            {
              'dayOfWeek': 'tuesday',
              'isAvailable': true,
              'periods': [
                {'startsAt': '09:00', 'endsAt': '17:00'},
              ],
              'breaks': [
                {'startsAt': '12:00', 'endsAt': '13:00'},
              ],
            },
          ],
        });

        final tuesday = schedule.days[1];
        expect(schedule.staffId, 'stf_1');
        expect(tuesday.dayOfWeek, 'tuesday');
        expect(tuesday.isAvailable, isTrue);
        expect(tuesday.breaks, [
          const TimePeriod(start: '12:00', end: '13:00'),
        ]);
        expect(schedule.days.where((d) => d.isAvailable), hasLength(1));
      },
    );

    test('an unavailable day drops its breaks as well as its periods', () {
      final json = staffScheduleToJson(
        const StaffSchedule(
          staffId: 'stf_1',
          timezone: 'Asia/Jakarta',
          days: [
            StaffDay(
              dayOfWeek: 'monday',
              isAvailable: false,
              periods: [TimePeriod(start: '09:00', end: '17:00')],
              breaks: [TimePeriod(start: '12:00', end: '13:00')],
            ),
          ],
        ),
      );

      final monday = (json['days']! as List<dynamic>).single as Map;
      expect(monday['isAvailable'], isFalse);
      expect(monday['periods'], isEmpty);
      // A stray break is SCHEDULE_INVALID_PERIOD on the backend.
      expect(monday['breaks'], isEmpty);
    });
  });

  test('closed dates map id, date and reason', () {
    final items = closedDatesFromJson({
      'items': [
        {'id': 'cld_1', 'date': '2026-08-17', 'reason': 'Public holiday'},
        {'id': 'cld_2', 'date': '2026-08-18'},
      ],
    });

    expect(items, hasLength(2));
    expect(items.first.reason, 'Public holiday');
    expect(items.last.reason, isNull);
  });
}
