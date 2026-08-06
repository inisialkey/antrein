import 'package:antrein/core/network/interceptors/logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redactHeaders', () {
    test('hides credential headers regardless of casing', () {
      final result = redactHeaders({
        'Authorization': 'Bearer secret-token',
        'Cookie': 'sid=abc',
        'Accept': 'application/json',
      });

      expect(result['Authorization'], '<redacted>');
      expect(result['Cookie'], '<redacted>');
      expect(result['Accept'], 'application/json');
    });
  });

  group('redactBody', () {
    test('hides secrets at any depth and keeps the rest readable', () {
      final result = redactBody({
        'email': 'demo@antrein.test',
        'password': 'DemoAntre123',
        'device': {'deviceId': 'dev_1', 'pushToken': 'osid-123'},
      });

      expect(result, contains('demo@antrein.test'));
      expect(result, isNot(contains('DemoAntre123')));
      expect(result, isNot(contains('osid-123')));
      expect(result, contains('dev_1'));
    });

    test('truncates a long body', () {
      final result = redactBody({'blob': 'x' * 2000});

      expect(result.length, lessThan(1000));
      expect(result, contains('chars)'));
    });

    test('never throws on an unencodable body', () {
      expect(redactBody(const Stream<int>.empty()), isA<String>());
      expect(redactBody(null), '<empty>');
    });
  });
}
