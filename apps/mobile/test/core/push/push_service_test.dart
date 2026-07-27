import 'package:antrein/core/push/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // No ONESIGNAL_APP_ID dart-define in the test build, so the service is
  // disabled and must never touch the (unregistered) OneSignal plugin.
  group('PushService (unconfigured build)', () {
    final push = PushService();

    test('is disabled and reports a null push token', () {
      expect(push.enabled, isFalse);
      expect(push.pushToken, isNull);
    });

    test('start() is a no-op that resolves without hitting the plugin', () {
      expect(push.start(), completes);
    });

    test('onTokenChange() registers no observer and never fires', () {
      var fired = false;
      push.onTokenChange(() => fired = true);
      expect(fired, isFalse);
    });
  });
}
