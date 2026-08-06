import 'dart:async';

import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/booking/booking.dart';
import 'package:antrein/features/business_bookings/presentation/cubit/business_bookings_cubit.dart';
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// Counter sheet for one booking: customer contact, payment state, and the
/// three staff actions (§73 confirm, §68.1 cancel, §68 no-show).
///
/// Holds the id, not the booking — every resync flows through, so a figure the
/// staff acts on is never one the list has already superseded.
class BookingDeskSheet extends StatelessWidget {
  const BookingDeskSheet({
    required this.bookingId,
    required this.canConfirmPayment,
    required this.canManageBooking,
    required this.canManageQueue,
    super.key,
  });

  final String bookingId;
  final bool canConfirmPayment;
  final bool canManageBooking;
  final bool canManageQueue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    return BlocConsumer<BusinessBookingsCubit, BusinessBookingsState>(
      listenWhen: (previous, current) =>
          previous.actionDone != current.actionDone &&
          current.actionDone != null,
      // The list behind the sheet already carries the outcome snackbar.
      listener: (context, _) => Navigator.of(context).pop(),
      builder: (context, state) {
        final booking = state.bookingById(bookingId);
        if (booking == null) return const SizedBox.shrink();
        final busy = state.actingBookingId == bookingId;
        final summary = booking.paymentSummary;
        final due = booking.outstanding;

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              Dimens.space16.r,
              0,
              Dimens.space16.r,
              Dimens.space16.r,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        booking.customerName ?? l10n.deskNoCustomerName,
                        style: context.textTheme.titleMedium,
                      ),
                    ),
                    BookingStatusChip(status: booking.status),
                  ],
                ),
                Text(
                  booking.bookingCode,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
                const Gap(Dimens.space16),
                if (booking.customerPhone case final phone?)
                  _Row(label: l10n.deskPhone, value: phone),
                _Row(label: l10n.summaryService, value: booking.serviceName),
                _Row(
                  label: l10n.summaryStaff,
                  value: booking.staffName ?? '-',
                ),
                _Row(
                  label: l10n.summarySchedule,
                  value: booking.scheduledAt == null
                      ? l10n.deskWalkIn
                      : DateFormat(
                          'EEEE, d MMMM yyyy · HH:mm',
                          locale,
                        ).format(booking.scheduledAt!.toLocal()),
                ),
                if (booking.customerNotes case final notes?
                    when notes.isNotEmpty)
                  _Row(label: l10n.deskNotes, value: notes),
                if (booking.internalNotes case final notes?
                    when notes.isNotEmpty)
                  _Row(label: l10n.deskInternalNotes, value: notes),
                const Divider(height: Dimens.space24),
                Text(
                  l10n.deskPaymentSection,
                  style: context.textTheme.titleSmall,
                ),
                const Gap(Dimens.space8),
                _Row(
                  label: l10n.totalLabel,
                  value: summary?.totalAmount.formatted ?? '-',
                ),
                _Row(
                  label: l10n.deskPaidAmount,
                  value: summary?.paidAmount.formatted ?? '-',
                ),
                _Row(label: l10n.deskRemaining, value: due.formatted),
                const Gap(Dimens.space16),
                if (canConfirmPayment && _canTakeMoney(booking)) ...[
                  AppButton(
                    label: l10n.deskConfirmPayment(due.formatted),
                    loading: busy,
                    onPressed: () => unawaited(_pickMethod(context, booking)),
                  ),
                  const Gap(Dimens.space8),
                ],
                if (canManageQueue && booking.status == BookingStatus.confirmed)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => unawaited(_confirmNoShow(context, booking)),
                    child: Text(l10n.deskNoShow),
                  ),
                if (canManageBooking && _canCancel(booking))
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => unawaited(_confirmCancel(context, booking)),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colorScheme.error,
                    ),
                    child: Text(l10n.deskCancel),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// §73 only settles money that is still owed; a terminal booking never is.
  static bool _canTakeMoney(Booking booking) =>
      booking.outstanding.amount > 0 &&
      !const {
        BookingStatus.cancelled,
        BookingStatus.expired,
        BookingStatus.noShow,
      }.contains(booking.status);

  /// Mirrors the backend guard (`assertCancellable`): only a booking that has
  /// not started yet, and only from the two pre-service statuses.
  static bool _canCancel(Booking booking) =>
      const {
        BookingStatus.pendingPayment,
        BookingStatus.confirmed,
      }.contains(booking.status) &&
      (booking.scheduledAt == null ||
          booking.scheduledAt!.isAfter(DateTime.now()));

  /// One tap per method — the amount is fixed to the outstanding balance, which
  /// is the only figure §73 accepts, so there is nothing to type.
  ///
  /// ponytail: the optional `note` is skipped; the audit row already records
  /// actor, amount and method. Add a field if a business asks for the note.
  Future<void> _pickMethod(BuildContext context, Booking booking) async {
    final l10n = context.l10n;
    final cubit = context.read<BusinessBookingsCubit>();
    final method = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          l10n.deskConfirmPaymentTitle(booking.outstanding.formatted),
        ),
        children: [
          for (final method in payAtLocationMethods)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, method),
              child: Text(_methodLabel(l10n, method)),
            ),
        ],
      ),
    );
    if (method != null) {
      await cubit.confirmPayment(booking: booking, method: method);
    }
  }

  Future<void> _confirmCancel(BuildContext context, Booking booking) async {
    final l10n = context.l10n;
    final cubit = context.read<BusinessBookingsCubit>();
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deskCancelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.deskCancelWarning),
            const Gap(Dimens.space12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 500,
              decoration: InputDecoration(hintText: l10n.deskCancelHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.deskCancel),
          ),
        ],
      ),
    );
    controller.dispose();
    // §68.1 requires a reason — an empty one aborts.
    if (reason != null && reason.isNotEmpty) {
      await cubit.cancelBooking(
        booking: booking,
        reasonCode: 'business_unavailable',
        reason: reason,
      );
    }
  }

  Future<void> _confirmNoShow(BuildContext context, Booking booking) async {
    final l10n = context.l10n;
    final cubit = context.read<BusinessBookingsCubit>();
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deskNoShowTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          decoration: InputDecoration(hintText: l10n.notesOptional),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deskNoShow),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed ?? false) {
      await cubit.markNoShow(booking: booking, reason: reason);
    }
  }

  static String _methodLabel(AppLocalizations l10n, String method) =>
      switch (method) {
        'cash' => l10n.deskMethodCash,
        'qris_manual' => l10n.deskMethodQris,
        'bank_transfer_manual' => l10n.deskMethodTransfer,
        'card_terminal' => l10n.deskMethodCard,
        _ => l10n.deskMethodOther,
      };
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: Dimens.space4.r),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110.r,
          child: Text(label, style: context.textTheme.bodySmall),
        ),
        const Gap.horizontal(Dimens.space8),
        Expanded(
          child: Text(
            value,
            style: context.textTheme.bodyMedium,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}
