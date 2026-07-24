import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Brand header for the auth screens: a mark, the app name, and an optional
/// subtitle. Uses a Material icon placeholder until brand art is wired
/// (see `AppLogo` / `assets/images/` — deferred to hardening).
class AuthHeader extends StatelessWidget {
  const AuthHeader({this.subtitle, super.key});

  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(
        Icons.content_cut,
        size: Dimens.iconXl.r,
        color: context.colorScheme.primary,
      ),
      const Gap(Dimens.space8),
      Text('AntreIn', style: context.textTheme.headlineMedium),
      if (subtitle != null) ...[
        const Gap(Dimens.space4),
        Text(
          subtitle!,
          style: context.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ],
  );
}
