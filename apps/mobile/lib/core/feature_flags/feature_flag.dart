/// Feature flags — one named key per flag with a safe in-binary default.
/// The default is the value used when the fetch fails; a kill-switch defaults
/// to the current-shipped behaviour, never the new path.
///
/// Placeholder set for M3 — real flags arrive with the features that gate on
/// them (e.g. realtime queue in M8).
enum FeatureFlag {
  realtimeQueue('realtime_queue', defaultValue: false);

  const FeatureFlag(this.key, {required this.defaultValue});

  final String key;
  final bool defaultValue;
}
