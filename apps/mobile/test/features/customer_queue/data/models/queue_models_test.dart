import 'package:antrein/features/customer_queue/data/models/queue_models.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueueEntryModel', () {
    final json = <String, dynamic>{
      'id': 'que_1',
      'bookingId': 'bkg_1',
      'businessId': 'biz_1',
      'outletId': 'out_1',
      'businessDate': '2026-07-22',
      'queueNumber': 12,
      'displayNumber': 'A012',
      'status': 'waiting',
      'peopleAhead': 3,
      'currentServingNumber': 'A009',
      'estimatedWaitMinutes': 45,
      'calledAt': null,
      'version': 4,
      'updatedAt': '2026-07-22T09:50:00+07:00',
    };

    test('maps the §80 resource to the entity', () {
      final entity = QueueEntryModel.fromJson(json).toEntity();

      expect(entity.id, 'que_1');
      expect(entity.bookingId, 'bkg_1');
      expect(entity.businessDate, '2026-07-22');
      expect(entity.displayNumber, 'A012');
      expect(entity.status, QueueStatus.waiting);
      expect(entity.peopleAhead, 3);
      expect(entity.currentServingNumber, 'A009');
      expect(entity.estimatedWaitMinutes, 45);
      expect(entity.version, 4);
      expect(entity.isTerminal, isFalse);
      expect(entity.isCalled, isFalse);
    });

    test('unknown status maps to QueueStatus.unknown, never throws', () {
      final entity = QueueEntryModel.fromJson({
        ...json,
        'status': 'teleported',
      }).toEntity();
      expect(entity.status, QueueStatus.unknown);
    });

    test('a called entry is flagged for the "your turn" banner', () {
      final entity = QueueEntryModel.fromJson({
        ...json,
        'status': 'called',
      }).toEntity();
      expect(entity.isCalled, isTrue);
    });

    test(
      'the check-in §64 queue block (no version/timestamps) defaults safely',
      () {
        final entity = QueueEntryModel.fromJson(<String, dynamic>{
          'id': 'que_1',
          'bookingId': 'bkg_1',
          'businessDate': '2026-07-22',
          'queueNumber': 1,
          'displayNumber': 'A001',
          'status': 'waiting',
          'peopleAhead': 0,
          'estimatedWaitMinutes': 0,
        }).toEntity();

        expect(entity.version, 0);
        expect(entity.currentServingNumber, isNull);
        expect(entity.calledAt, isNull);
      },
    );
  });
}
