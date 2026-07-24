import 'package:antrein/core/ui/dimens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Primary action button. Thin wrapper over [FilledButton] — colors/shape come
/// from the theme, not per-instance styling. Shows a spinner and blocks taps
/// while [loading]; full-width unless [expanded] is false.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox.square(
              dimension: Dimens.iconSm.r,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
