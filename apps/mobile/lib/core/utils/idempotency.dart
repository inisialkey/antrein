import 'dart:math';

/// A fresh `Idempotency-Key` for one logical submission (api-contract §23).
///
/// Cubits mint the key when a submission *begins* and keep it across transport
/// retries; they drop it once the backend answers, because a stored key replays
/// the stored outcome — including a stored rejection.
String newIdempotencyKey() {
  final random = Random();
  final suffix = List.generate(
    4,
    (_) => random.nextInt(1 << 32).toRadixString(16),
  ).join();
  return 'idem_${DateTime.now().microsecondsSinceEpoch}_$suffix';
}
