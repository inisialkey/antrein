import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/presentation/cubit/booking_detail_cubit.dart';
import 'package:antrein/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:antrein/features/customer_queue/customer_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Booking detail (§62): status, schedule, payment summary, cancellation, and
/// — while awaiting payment — the checkout link + status refresh (§72).
class BookingDetailPage extends StatelessWidget {
  const BookingDetailPage({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<BookingDetailCubit>();
      unawaited(cubit.load(bookingId));
      return cubit;
    },
    child: const _BookingDetailView(),
  );
}

class _BookingDetailView extends StatelessWidget {
  const _BookingDetailView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<BookingDetailCubit, BookingDetailState>(
      listenWhen: (previous, current) =>
          previous.message != current.message && current.message != null ||
          !previous.didCancel && current.didCancel,
      listener: (context, state) {
        final text = state.didCancel ? l10n.bookingCancelled : state.message;
        if (text != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(text)));
        }
      },
      builder: (context, state) => AppScaffold(
        appBar: AppBar(title: Text(l10n.bookingDetailTitle)),
        body: switch (state.status) {
          BookingDetailStatus.initial ||
          BookingDetailStatus.loading => const AppLoading(),
          BookingDetailStatus.failure => AppEmpty(
            message: state.message ?? l10n.bookingsLoadFailed,
            icon: Icons.error_outline,
          ),
          BookingDetailStatus.success => _Loaded(state: state),
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});

  final BookingDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final booking = state.booking!;
    final locale = Localizations.localeOf(context).toString();
    final schedule = booking.scheduledAt == null
        ? '-'
        : DateFormat(
            'EEEE, d MMMM yyyy · HH:mm',
            locale,
          ).format(booking.scheduledAt!.toLocal());
    final summary = booking.paymentSummary;

    return ListView(
      padding: EdgeInsets.all(Dimens.space16.r),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                booking.bookingCode,
                style: context.textTheme.titleLarge,
              ),
            ),
            BookingStatusChip(status: booking.status),
          ],
        ),
        const Gap(Dimens.space16),
        if (booking.status == BookingStatus.confirmed) ...[
          _CheckInCard(bookingId: booking.id),
          const Gap(Dimens.space16),
        ],
        if (_showsQueueLink(booking.status)) ...[
          _ViewQueueButton(bookingId: booking.id),
          const Gap(Dimens.space16),
        ],
        if (booking.isAwaitingPayment) ...[
          _PendingPaymentCard(state: state),
          const Gap(Dimens.space16),
        ],
        _InfoCard(
          rows: [
            (l10n.summaryBusiness, booking.businessName),
            (l10n.summaryOutlet, booking.outletName),
            if (booking.outletAddress != null)
              (l10n.summaryAddress, booking.outletAddress!),
            (l10n.summaryService, booking.serviceName),
            (l10n.summaryStaff, booking.staffName ?? '-'),
            (l10n.summarySchedule, schedule),
            (
              l10n.summaryDuration,
              '${booking.durationMinutes} ${l10n.minutesShort}',
            ),
            if (booking.customerNotes?.isNotEmpty ?? false)
              (l10n.notesOptional, booking.customerNotes!),
          ],
        ),
        if (summary != null) ...[
          const Gap(Dimens.space16),
          Text(l10n.paymentSection, style: context.textTheme.titleMedium),
          const Gap(Dimens.space8),
          _InfoCard(
            rows: [
              (l10n.totalLabel, summary.totalAmount.formatted),
              (l10n.paidLabel, summary.paidAmount.formatted),
              (l10n.remainingLabel, summary.remainingAmount.formatted),
            ],
          ),
        ],
        if (booking.canCancel) ...[
          const Gap(Dimens.space24),
          if (booking.refundEstimate != null)
            Padding(
              padding: EdgeInsets.only(bottom: Dimens.space8.r),
              child: Text(
                l10n.refundEstimateLabel(booking.refundEstimate!.formatted),
                style: context.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colorScheme.error,
              side: BorderSide(color: context.colorScheme.error),
              minimumSize: Size.fromHeight(Dimens.buttonHeight.r),
            ),
            onPressed: state.isCancelling
                ? null
                : () => _confirmCancel(context),
            child: state.isCancelling
                ? SizedBox.square(
                    dimension: Dimens.iconSm.r,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.cancelBookingAction),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<BookingDetailCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cancelConfirmTitle),
        content: Text(l10n.cancelConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.keepBooking),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.yesCancelBooking),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await cubit.cancel(reasonCode: 'customer_changed_plan');
    }
  }
}

class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({required this.state});

  final BookingDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final payment = state.pendingPayment;
    final checkoutUrl = payment?.checkoutUrl;
    final scheme = context.colorScheme;
    final locale = Localizations.localeOf(context).toString();

    return Card(
      color: context.appColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: EdgeInsets.all(Dimens.space16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: context.appColors.warning,
                  size: Dimens.iconMd.r,
                ),
                const Gap.horizontal(Dimens.space8),
                Expanded(
                  child: Text(
                    l10n.awaitingPaymentTitle,
                    style: context.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const Gap(Dimens.space8),
            if (payment?.expiresAt != null)
              Text(
                l10n.payBefore(
                  DateFormat(
                    'HH:mm',
                    locale,
                  ).format(payment!.expiresAt!.toLocal()),
                ),
                style: context.textTheme.bodySmall,
              ),
            if (checkoutUrl != null) ...[
              const Gap(Dimens.space12),
              // ponytail: the sandbox checkout URL is not a real page yet —
              // copy-to-clipboard stands in for url_launcher until a real
              // gateway (Midtrans Snap) lands.
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: checkoutUrl));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.checkoutLinkCopied)),
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(Dimens.space12.r),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(Dimens.radiusSm.r),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          checkoutUrl,
                          style: context.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.copy, size: Dimens.iconSm.r),
                    ],
                  ),
                ),
              ),
            ],
            const Gap(Dimens.space12),
            AppButton(
              label: l10n.checkPaymentStatus,
              loading: state.isRefreshingPayment,
              onPressed: () =>
                  context.read<BookingDetailCubit>().refreshPaymentStatus(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(Dimens.space16.r),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: Dimens.space4.r),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96.r,
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
            ),
        ],
      ),
    ),
  );
}

/// Booking is in the active queue (post check-in) — offer the live queue view.
bool _showsQueueLink(BookingStatus status) =>
    status == BookingStatus.checkedIn ||
    status == BookingStatus.waiting ||
    status == BookingStatus.called ||
    status == BookingStatus.inService;

String _checkInErrorText(BuildContext context, String? code, String fallback) {
  final l10n = context.l10n;
  return switch (code) {
    ApiErrorCodes.bookingCheckInTooEarly => l10n.checkInTooEarly,
    ApiErrorCodes.bookingCheckInTooLate => l10n.checkInTooLate,
    ApiErrorCodes.queueEntryAlreadyExists => l10n.checkInAlreadyIn,
    ApiErrorCodes.outletQueueClosed => l10n.checkInQueueClosed,
    _ => fallback.isEmpty ? l10n.checkInFailed : fallback,
  };
}

/// Check-in prompt shown on a confirmed booking (§64). Self-contained CheckInCubit.
class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<CheckInCubit>(),
    child: _CheckInCardView(bookingId: bookingId),
  );
}

class _CheckInCardView extends StatelessWidget {
  const _CheckInCardView({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<CheckInCubit, CheckInState>(
      listener: (context, state) {
        switch (state) {
          case CheckInSuccess():
            // Booking is now `waiting`; refresh detail and open the live queue.
            unawaited(context.read<BookingDetailCubit>().load(bookingId));
            unawaited(
              context.pushNamed(
                Routes.customerQueue.name,
                pathParameters: {'bookingId': bookingId},
              ),
            );
          case CheckInError(:final message, :final code):
            context.showSnackBar(_checkInErrorText(context, code, message));
          case CheckInInitial():
          case CheckInSubmitting():
        }
      },
      builder: (context, state) => Card(
        color: context.appColors.success.withValues(alpha: 0.08),
        child: Padding(
          padding: EdgeInsets.all(Dimens.space16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.how_to_reg_outlined,
                    color: context.appColors.success,
                    size: Dimens.iconMd.r,
                  ),
                  const Gap.horizontal(Dimens.space8),
                  Expanded(
                    child: Text(
                      l10n.checkInTitle,
                      style: context.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const Gap(Dimens.space8),
              Text(l10n.checkInPrompt, style: context.textTheme.bodySmall),
              const Gap(Dimens.space12),
              AppButton(
                label: l10n.checkInAction,
                loading: state is CheckInSubmitting,
                onPressed: () => context.read<CheckInCubit>().submit(bookingId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewQueueButton extends StatelessWidget {
  const _ViewQueueButton({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) => AppButton(
    label: context.l10n.viewQueueAction,
    onPressed: () => unawaited(
      context.pushNamed(
        Routes.customerQueue.name,
        pathParameters: {'bookingId': bookingId},
      ),
    ),
  );
}
