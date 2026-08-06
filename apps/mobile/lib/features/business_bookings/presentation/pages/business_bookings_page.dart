import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/features/booking/booking.dart';
import 'package:antrein/features/business_bookings/presentation/cubit/business_bookings_cubit.dart';
import 'package:antrein/features/business_bookings/presentation/widgets/booking_desk_sheet.dart';
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// Operational booking desk (contract §65, §68, §68.1, §73). One outlet-day of
/// bookings; tapping a row opens the counter sheet where payment is recorded,
/// the booking is cancelled, or a no-show is marked.
///
/// Permissions are read from the signed-in membership rather than threaded in as
/// props — this is a route of its own, not a child of the queue board.
class BusinessBookingsPage extends StatelessWidget {
  const BusinessBookingsPage({
    required this.businessId,
    required this.outletId,
    super.key,
  });

  final String businessId;
  final String outletId;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final membership = authState is AuthAuthenticated
        ? authState.user.primaryMembership
        : null;

    return BlocProvider(
      create: (_) {
        final cubit = getIt<BusinessBookingsCubit>();
        unawaited(cubit.load(businessId: businessId, outletId: outletId));
        return cubit;
      },
      child: _BookingDeskView(
        canConfirmPayment: membership?.can('payment.confirm') ?? false,
        canManageBooking: membership?.can('booking.manage') ?? false,
        canManageQueue: membership?.can('queue.manage') ?? false,
      ),
    );
  }
}

class _BookingDeskView extends StatelessWidget {
  const _BookingDeskView({
    required this.canConfirmPayment,
    required this.canManageBooking,
    required this.canManageQueue,
  });

  final bool canConfirmPayment;
  final bool canManageBooking;
  final bool canManageQueue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.deskTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.queueRefresh,
            onPressed: () =>
                unawaited(context.read<BusinessBookingsCubit>().refresh()),
          ),
        ],
      ),
      body: Column(
        children: [
          const _DateBar(),
          const Divider(height: 1),
          Expanded(
            child: BlocConsumer<BusinessBookingsCubit, BusinessBookingsState>(
              listenWhen: (previous, current) =>
                  previous.actionError != current.actionError ||
                  previous.actionDone != current.actionDone,
              listener: (context, state) {
                final message = state.actionError ?? _doneMessage(l10n, state);
                if (message == null) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(message)));
              },
              builder: (context, state) => switch (state.status) {
                BookingDeskStatus.initial ||
                BookingDeskStatus.loading => const AppLoading(),
                BookingDeskStatus.failure => AppEmpty(
                  message: state.message ?? l10n.deskLoadFailed,
                  icon: Icons.error_outline,
                ),
                BookingDeskStatus.empty => RefreshIndicator(
                  onRefresh: context.read<BusinessBookingsCubit>().refresh,
                  // A scrollable is required for pull-to-refresh to fire.
                  child: ListView(
                    children: [
                      SizedBox(height: 120.r),
                      AppEmpty(
                        message: l10n.deskEmpty,
                        icon: Icons.event_note_outlined,
                      ),
                    ],
                  ),
                ),
                BookingDeskStatus.success => RefreshIndicator(
                  onRefresh: context.read<BusinessBookingsCubit>().refresh,
                  child: ListView.separated(
                    padding: EdgeInsets.all(Dimens.space16.r),
                    itemCount: state.bookings.length,
                    separatorBuilder: (_, _) => const Gap(Dimens.space12),
                    itemBuilder: (context, index) {
                      final booking = state.bookings[index];
                      return _DeskCard(
                        booking: booking,
                        onTap: () => _openSheet(context, booking.id),
                      );
                    },
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _doneMessage(AppLocalizations l10n, BusinessBookingsState state) =>
      switch (state.actionDone) {
        BookingDeskAction.paymentConfirmed => l10n.deskPaymentConfirmed,
        BookingDeskAction.cancelled => l10n.deskCancelled,
        BookingDeskAction.noShow => l10n.deskNoShowDone,
        null => null,
      };

  void _openSheet(BuildContext context, String bookingId) {
    final cubit = context.read<BusinessBookingsCubit>();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: BookingDeskSheet(
            bookingId: bookingId,
            canConfirmPayment: canConfirmPayment,
            canManageBooking: canManageBooking,
            canManageQueue: canManageQueue,
          ),
        ),
      ),
    );
  }
}

/// Day switcher. Unlike the reports one this may step forward — bookings are
/// scheduled ahead — so it caps a year out rather than at today.
class _DateBar extends StatelessWidget {
  const _DateBar();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BusinessBookingsCubit>();
    final shown = context.select<BusinessBookingsCubit, DateTime>(
      (c) => c.state.date ?? DateTime.now(),
    );
    final locale = Localizations.localeOf(context).toString();

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => unawaited(
            cubit.changeDate(shown.subtract(const Duration(days: 1))),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () => unawaited(_pickDate(context, cubit, shown)),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: Dimens.space8.r),
              child: Text(
                DateFormat('EEEE, d MMMM yyyy', locale).format(shown),
                style: context.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () =>
              unawaited(cubit.changeDate(shown.add(const Duration(days: 1)))),
        ),
      ],
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    BusinessBookingsCubit cubit,
    DateTime shown,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: shown,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) await cubit.changeDate(picked);
  }
}

class _DeskCard extends StatelessWidget {
  const _DeskCard({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final time = booking.scheduledAt == null
        ? l10n.deskWalkIn
        : DateFormat('HH:mm', locale).format(booking.scheduledAt!.toLocal());

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(Dimens.space12.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(time, style: context.textTheme.titleSmall),
                  const Gap.horizontal(Dimens.space8),
                  Expanded(
                    child: Text(
                      booking.customerName ?? l10n.deskNoCustomerName,
                      style: context.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  BookingStatusChip(status: booking.status),
                ],
              ),
              const Gap(Dimens.space8),
              Text(booking.serviceName, style: context.textTheme.bodyMedium),
              const Gap(Dimens.space8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.bookingCode,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ),
                  _PaymentBadge(booking: booking),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final due = booking.outstanding;
    final settled = due.amount <= 0;
    final color = settled
        ? context.appColors.success
        : context.appColors.warning;

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
        settled ? l10n.deskSettled : l10n.deskOutstanding(due.formatted),
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
