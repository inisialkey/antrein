import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/gap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Centered empty / no-data placeholder: an icon over a message.
class AppEmpty extends StatelessWidget {
  const AppEmpty({
    required this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: Dimens.iconXl.r,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const Gap(Dimens.space12),
        Text(
          message,
          style: context.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
