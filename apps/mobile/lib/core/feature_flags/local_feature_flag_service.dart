import 'package:antrein/core/feature_flags/feature_flag.dart';
import 'package:antrein/core/feature_flags/feature_flag_service.dart';
import 'package:antrein/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// The only [FeatureFlagService] binding for the MVP — an in-memory stand-in
/// for a remote source (Firebase Remote Config / ConfigCat). Registered for
/// every environment; reads fall back to each flag's in-binary default. Swap
/// the adapter later to fetch remotely — the Port and call sites stay unchanged.
@LazySingleton(as: FeatureFlagService)
class LocalFeatureFlagService implements FeatureFlagService {
  LocalFeatureFlagService();

  final Map<String, bool> _remote = {};
  final Map<String, bool> _devOverride = {};

  @override
  Future<void> initialize() async {
    try {
      // Simulate a remote fetch+activate (replace with the SDK call). No flags
      // are overridden yet, so every read resolves to its default.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    } on Object catch (e) {
      // ANY fetch failure falls back to cache/default — never throws into
      // bootstrap.
      AppLogger.w('Feature flag fetch failed, using defaults', error: e);
    }
  }

  @override
  bool isEnabled(FeatureFlag flag) {
    if (kDebugMode && _devOverride.containsKey(flag.key)) {
      return _devOverride[flag.key]!;
    }
    return _remote[flag.key] ?? flag.defaultValue;
  }

  /// kDebugMode-only override (debug menu / tests). Never compiled into release.
  @visibleForTesting
  void setDevOverride(FeatureFlag flag, {required bool enabled}) {
    if (kDebugMode) {
      _devOverride[flag.key] = enabled;
    }
  }
}
