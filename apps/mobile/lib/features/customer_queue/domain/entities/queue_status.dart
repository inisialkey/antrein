/// Queue lifecycle (api-contract §80, realtime-queue §8). Wire strings mirror the
/// backend `queue_entries.status` column; unknown tolerates forward-compat values.
enum QueueStatus {
  waiting('waiting'),
  called('called'),
  skipped('skipped'),
  inService('in_service'),
  completed('completed'),
  cancelled('cancelled'),
  noShow('no_show'),
  unknown('unknown');

  const QueueStatus(this.wire);

  final String wire;

  static QueueStatus fromWire(String? value) => QueueStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => QueueStatus.unknown,
  );

  /// Terminal queue states — nothing more will happen, so stop polling.
  bool get isTerminal =>
      this == completed || this == cancelled || this == noShow;

  /// The customer is being called to the service area.
  bool get isCalled => this == called;
}
