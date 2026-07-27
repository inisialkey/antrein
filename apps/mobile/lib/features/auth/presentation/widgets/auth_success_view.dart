import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Centered success confirmation: a success-coloured icon, a message, and a
/// single primary action. Shared by the forgot/reset password success states.
class AuthSuccessView extends StatelessWidget {
  const AuthSuccessView({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.icon = Icons.check_circle_outline,
    super.key,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(Dimens.space24.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Dimens.iconXl.r, color: context.appColors.success),
          const Gap(Dimens.space16),
          Text(
            message,
            style: context.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const Gap(Dimens.space24),
          AppButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    ),
  );
}
