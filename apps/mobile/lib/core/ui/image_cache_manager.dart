import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for network images, stored under the OS cache directory.
/// Tuned for app thumbnails: keep ~200 objects, expire after 7 days.
class AppImageCacheManager {
  AppImageCacheManager._();

  static const _key = 'appImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );
}
