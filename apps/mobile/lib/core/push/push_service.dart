import 'package:injectable/injectable.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// OneSignal push wrapper (ADR 0022/0044). A no-op unless `ONESIGNAL_APP_ID` is
/// supplied at build time (`--dart-define=ONESIGNAL_APP_ID=...`), so dev, CI and
/// test builds pull in no push runtime at all. The subscription id it exposes is
/// exactly the device `pushToken` the backend OneSignal adapter targets
/// (`include_subscription_ids`).
@lazySingleton
class PushService {
  PushService() : _appId = const String.fromEnvironment('ONESIGNAL_APP_ID');

  final String _appId;
  bool _started = false;

  bool get enabled => _appId.isNotEmpty;

  /// Initialize the SDK once and prompt for permission. Safe to call on every
  /// launch — a no-op when unconfigured or already started.
  Future<void> start() async {
    if (!enabled || _started) return;
    _started = true;
    await OneSignal.initialize(_appId);
    await OneSignal.Notifications.requestPermission(true);
  }

  /// The device's current OneSignal subscription id, or null when unconfigured
  /// or the device has not subscribed yet.
  String? get pushToken => enabled ? OneSignal.User.pushSubscription.id : null;

  /// Calls [onChange] when the subscription id first appears or changes, so a
  /// token that arrives after sign-in (permission granted late, APNs/FCM
  /// registration lag) still reaches the backend.
  void onTokenChange(void Function() onChange) {
    if (!enabled) return;
    OneSignal.User.pushSubscription.addObserver((_) => onChange());
  }
}
