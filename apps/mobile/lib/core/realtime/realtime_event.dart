/// A parsed WebSocket event envelope (api-contract §104). Transport-level DTO:
/// feature cubits consume it and recover authoritative state over REST — the UI
/// never sees it directly.
class RealtimeEvent {
  const RealtimeEvent({
    required this.type,
    required this.resourceType,
    required this.resourceId,
    required this.version,
    required this.data,
  });

  /// Versioned event type, e.g. `queue.entry.updated.v1`.
  final String type;
  final String resourceType;
  final String resourceId;

  /// Monotonic resource version (0 when the event carries none).
  final int version;
  final Map<String, dynamic> data;

  /// Parse a raw socket payload, or null when it is not a versioned envelope
  /// (e.g. `subscription.joined.v1` acks, which carry no `type`).
  static RealtimeEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final type = raw['type'];
    if (type is! String) return null;
    final resource = raw['resource'];
    final resourceMap = resource is Map ? resource : const <String, dynamic>{};
    final data = raw['data'];
    return RealtimeEvent(
      type: type,
      resourceType: resourceMap['type'] as String? ?? '',
      resourceId: resourceMap['id'] as String? ?? '',
      version: (raw['version'] as num?)?.toInt() ?? 0,
      data: data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }
}
