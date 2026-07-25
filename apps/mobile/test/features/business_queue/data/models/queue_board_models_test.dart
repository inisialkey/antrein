import 'package:antrein/features/business_queue/data/models/queue_board_models.dart';
import 'package:antrein/features/customer_queue/customer_queue.dart'
    show QueueStatus;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueueBoardModel', () {
    final json = <String, dynamic>{
      'businessDate': '2026-07-26',
      'outletId': 'out_1',
      'isOpen': true,
      'version': 18,
      'currentServing': {
        'queueEntryId': 'que_serv',
        'displayNumber': 'A011',
        'bookingId': 'bkg_serv',
        'customer': {'name': 'Budi'},
        'service': {'name': 'Haircut'},
        'staff': {'id': 'stf_1', 'name': 'Aji'},
        'status': 'in_service',
        'version': 5,
        'checkedInAt': '2026-07-26T09:00:00+07:00',
      },
      'waiting': [
        {
          'queueEntryId': 'que_w1',
          'displayNumber': 'A012',
          'bookingId': 'bkg_w1',
          'customer': {'name': 'Andi'},
          'service': {'name': 'Haircut'},
          'staff': null,
          'status': 'waiting',
          'version': 2,
          'checkedInAt': '2026-07-26T09:05:00+07:00',
        },
        {
          'queueEntryId': 'que_w2',
          'displayNumber': 'A013',
          'bookingId': 'bkg_w2',
          'customer': {'name': null},
          'service': {'name': 'Shave'},
          'staff': null,
          'status': 'waiting',
          'version': 1,
          'checkedInAt': '2026-07-26T09:06:00+07:00',
        },
      ],
      'skipped': [
        {
          'queueEntryId': 'que_s1',
          'displayNumber': 'A009',
          'bookingId': 'bkg_s1',
          'customer': {'name': 'Eko'},
          'service': {'name': 'Color'},
          'staff': null,
          'status': 'skipped',
          'version': 3,
          'checkedInAt': '2026-07-26T08:50:00+07:00',
        },
      ],
      'updatedAt': '2026-07-26T09:10:00+07:00',
    };

    test('maps the §82 snapshot to the board entity', () {
      final board = QueueBoardModel.fromJson(json).toEntity();

      expect(board.businessDate, '2026-07-26');
      expect(board.outletId, 'out_1');
      expect(board.isOpen, isTrue);
      expect(board.version, 18);

      expect(board.currentServing?.displayNumber, 'A011');
      expect(board.currentServing?.status, QueueStatus.inService);
      expect(board.currentServing?.customerName, 'Budi');
      expect(board.currentServing?.serviceName, 'Haircut');
      expect(board.currentServing?.staffName, 'Aji');
      expect(board.currentServing?.version, 5);

      expect(board.waiting, hasLength(2));
      expect(board.waiting.first.displayNumber, 'A012');
      expect(board.waiting.first.status, QueueStatus.waiting);
      expect(board.skipped, hasLength(1));
      expect(board.skipped.first.status, QueueStatus.skipped);

      expect(board.activeCount, 4);
      expect(board.isEmpty, isFalse);
    });

    test(
      'a null customer name maps to null (the board shows a guest label)',
      () {
        final board = QueueBoardModel.fromJson(json).toEntity();
        expect(board.waiting[1].customerName, isNull);
      },
    );

    test('an empty snapshot is flagged empty', () {
      final board = QueueBoardModel.fromJson(<String, dynamic>{
        'businessDate': '2026-07-26',
        'outletId': 'out_1',
        'isOpen': true,
        'version': 1,
        'currentServing': null,
        'waiting': <dynamic>[],
        'skipped': <dynamic>[],
      }).toEntity();
      expect(board.isEmpty, isTrue);
      expect(board.activeCount, 0);
    });

    test('an unknown status tolerates forward-compat values', () {
      final board = QueueBoardModel.fromJson(<String, dynamic>{
        ...json,
        'currentServing': {
          ...json['currentServing'] as Map<String, dynamic>,
          'status': 'teleported',
        },
      }).toEntity();
      expect(board.currentServing?.status, QueueStatus.unknown);
    });
  });
}
