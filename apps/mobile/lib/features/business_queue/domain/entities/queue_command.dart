/// The versioned staff lifecycle commands over a queue entry (contract §83–§89).
/// Each is applied with the entry's `expectedVersion`; the backend rejects a
/// stale version with `QUEUE_VERSION_CONFLICT`. Walk-in (§67) and reorder (§90)
/// are separate flows, deliberately out of this set.
enum QueueCommand {
  call('call'),
  recall('recall'),
  skip('skip'),
  returnToWaiting('return-to-waiting'),
  startService('start-service'),
  complete('complete'),
  noShow('no-show');

  const QueueCommand(this.path);

  /// The endpoint path segment for `POST /businesses/{id}/queue/{entry}/{path}`.
  final String path;
}
