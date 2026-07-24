import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Renders the per-flavor brand logo, choosing the light or dark variant by the
/// current theme brightness. [size] is a raw logical dimension; `.r` is applied
/// here so callers pass plain numbers (e.g. `Dimens.logo`).
class AppLogo extends StatelessWidget {
  const AppLogo({this.size = Dimens.logo, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimension = size.r;
    return Image.asset(
      isDark ? Images.logoDark : Images.logo,
      width: dimension,
      height: dimension,
    );
  }
}
