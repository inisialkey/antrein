import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/image_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shared network image — cached to disk via [AppImageCacheManager], with a
/// placeholder and an error fallback. Use this instead of `Image.network` or a
/// raw `CachedNetworkImage` so caching/placeholder/error stay consistent.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.url,
    this.width,
    this.height,
    this.borderRadius,
    super.key,
  });

  final String url;
  final double? width;
  final double? height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? Dimens.radiusSm.r),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheManager: AppImageCacheManager.instance,
        placeholder: (context, _) => _Box(
          width: width,
          height: height,
          child: const Center(
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, _, _) => _Box(
          width: width,
          height: height,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.width, this.height});

  final Widget child;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: context.colorScheme.surfaceContainerHighest,
      child: child,
    );
  }
}
