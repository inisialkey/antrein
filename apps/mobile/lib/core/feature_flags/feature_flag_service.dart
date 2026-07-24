import 'package:antrein/core/feature_flags/feature_flag.dart';

/// Domain port for remote config / feature flags. Pure — no SDK import.
/// Reads are synchronous off the warm cache (a UI build must never await a
/// flag); only [initialize] touches the network.
abstract class FeatureFlagService {
  Future<void> initialize();

  bool isEnabled(FeatureFlag flag);
}
