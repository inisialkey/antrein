import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Localized, color-coded booking status pill.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({required this.status, super.key});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final (label, color) = switch (status) {
      BookingStatus.pendingPayment => (
        l10n.statusPendingPayment,
        context.appColors.warning,
      ),
      BookingStatus.confirmed => (
        l10n.statusConfirmed,
        context.appColors.success,
      ),
      BookingStatus.checkedIn => (l10n.statusCheckedIn, context.appColors.info),
      BookingStatus.inService => (l10n.statusInService, context.appColors.info),
      BookingStatus.completed => (l10n.statusCompleted, scheme.primary),
      BookingStatus.cancelled => (l10n.statusCancelled, scheme.error),
      BookingStatus.expired => (l10n.statusExpired, scheme.outline),
      BookingStatus.noShow => (l10n.statusNoShow, scheme.error),
      BookingStatus.unknown => (status.wire, scheme.outline),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Dimens.space8.r,
        vertical: Dimens.space4.r,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimens.radiusXl.r),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
