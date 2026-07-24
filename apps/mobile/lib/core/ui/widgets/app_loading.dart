import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/gap.dart';
import 'package:flutter/material.dart';

/// Centered progress indicator with an optional message.
class AppLoading extends StatelessWidget {
  const AppLoading({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (message != null) ...[
          const Gap(Dimens.space12),
          Text(message!, style: context.textTheme.bodyMedium),
        ],
      ],
    ),
  );
}
