import 'package:antrein/core/realtime/realtime_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealtimeEvent.tryParse', () {
    test('parses a versioned envelope (api-contract §104)', () {
      final event = RealtimeEvent.tryParse({
        'eventId': 'evt_1',
        'type': 'queue.entry.updated.v1',
        'resource': {'type': 'queue_entry', 'id': 'que_1'},
        'version': 5,
        'data': {'status': 'called', 'bookingId': 'bkg_1'},
      });

      expect(event, isNotNull);
      expect(event!.type, 'queue.entry.updated.v1');
      expect(event.resourceType, 'queue_entry');
      expect(event.resourceId, 'que_1');
      expect(event.version, 5);
      expect(event.data['bookingId'], 'bkg_1');
    });

    test('returns null for a non-map payload', () {
      expect(RealtimeEvent.tryParse('nope'), isNull);
      expect(RealtimeEvent.tryParse(null), isNull);
    });

    test(
      'returns null when the payload carries no type (subscription ack)',
      () {
        expect(
          RealtimeEvent.tryParse({'requestId': 'x', 'joined': <Object>[]}),
          isNull,
        );
      },
    );

    test('tolerates a missing resource, data, and version', () {
      final event = RealtimeEvent.tryParse({'type': 'connection.ready.v1'});

      expect(event, isNotNull);
      expect(event!.resourceType, '');
      expect(event.resourceId, '');
      expect(event.version, 0);
      expect(event.data, isEmpty);
    });
  });
}
