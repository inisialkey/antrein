import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Fixed empty space between widgets. Vertical by default, [Gap.horizontal] for
/// rows. [size] is a raw logical value (pass a `Dimens` token); `.r` is applied
/// here. Backed by [SizedBox] — not `Container`, and distinct from Flutter's
/// flex `Spacer`.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key}) : _horizontal = false;

  const Gap.horizontal(this.size, {super.key}) : _horizontal = true;

  final double size;
  final bool _horizontal;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _horizontal ? size.r : null,
    height: _horizontal ? null : size.r,
  );
}
