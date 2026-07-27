import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges one or more streams (e.g. a Cubit/Bloc `stream`) to a [Listenable]
/// so `GoRouter(refreshListenable: ...)` re-evaluates redirects on each event.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(List<Stream<dynamic>> streams) {
    notifyListeners();
    _subscriptions = streams
        .map(
          (stream) => stream.asBroadcastStream().listen(
            (dynamic _) => notifyListeners(),
          ),
        )
        .toList();
  }

  late final List<StreamSubscription<dynamic>> _subscriptions;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
