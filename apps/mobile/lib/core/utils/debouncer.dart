import 'dart:async';

import 'package:flutter/foundation.dart';

/// Delays [run]'s action until [duration] elapses without another call — the
/// last call wins. Use it for search-as-you-type, resize handlers, etc.
///
/// Call [dispose] (e.g. in `State.dispose`) to cancel a pending action; a live
/// debouncer holds a `Timer`, so leaking it leaks the timer.
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 300)});

  final Duration duration;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  bool get isPending => _timer?.isActive ?? false;

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
