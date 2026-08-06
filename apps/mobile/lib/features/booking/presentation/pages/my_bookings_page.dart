import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/presentation/cubit/my_bookings_cubit.dart';
import 'package:antrein/features/booking/presentation/widgets/booking_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Bookings tab (api-contract §61).
class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<MyBookingsCubit>();
      unawaited(cubit.load());
      return cubit;
    },
    child: const _MyBookingsView(),
  );
}

class _MyBookingsView extends StatefulWidget {
  const _MyBookingsView();

  @override
  State<_MyBookingsView> createState() => _MyBookingsViewState();
}

/// The tab keeps its state while a full-screen route (booking detail, queue,
/// the booking flow) covers it, so the list is stale by the time the user comes
/// back — bookings get created, cancelled and checked in up there. Watching the
/// router instead of [RouteAware]: the shell is a `StatefulShellRoute`, so this
/// page lives in a *branch* navigator that a root [RouteObserver] never sees.
class _MyBookingsViewState extends State<_MyBookingsView> {
  GoRouter? _router;
  bool _wasCovered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router != null) return;
    _router = GoRouter.of(context)..routerDelegate.addListener(_onNavigation);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onNavigation);
    super.dispose();
  }

  void _onNavigation() {
    if (!mounted) return;
    final onTab =
        _router!.state.matchedLocation == Routes.customerBookings.path;
    if (!onTab) {
      _wasCovered = true;
    } else if (_wasCovered) {
      _wasCovered = false;
      unawaited(context.read<MyBookingsCubit>().refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.tabBookings)),
      body: BlocBuilder<MyBookingsCubit, MyBookingsState>(
        builder: (context, state) => switch (state.status) {
          MyBookingsStatus.initial ||
          MyBookingsStatus.loading => const AppLoading(),
          MyBookingsStatus.failure => AppEmpty(
            message: state.message ?? l10n.bookingsLoadFailed,
            icon: Icons.error_outline,
          ),
          MyBookingsStatus.empty => AppEmpty(
            message: l10n.bookingsEmpty,
            icon: Icons.event_note_outlined,
          ),
          MyBookingsStatus.success => RefreshIndicator(
            onRefresh: () => context.read<MyBookingsCubit>().refresh(),
            child: ListView.separated(
              padding: EdgeInsets.all(Dimens.space16.r),
              itemCount: state.bookings.length,
              separatorBuilder: (_, _) => const Gap(Dimens.space12),
              itemBuilder: (context, index) {
                final booking = state.bookings[index];
                return _BookingCard(
                  booking: booking,
                  // No refresh-on-return here — [_onNavigation] covers it.
                  onTap: () => unawaited(
                    context.pushNamed(
                      Routes.bookingDetail.name,
                      pathParameters: {'bookingId': booking.id},
                    ),
                  ),
                );
              },
            ),
          ),
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final schedule = booking.scheduledAt == null
        ? '-'
        : DateFormat(
            'EEE, d MMM yyyy · HH:mm',
            locale,
          ).format(booking.scheduledAt!.toLocal());
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
                  Expanded(
                    child: Text(
                      booking.businessName,
                      style: context.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  BookingStatusChip(status: booking.status),
                ],
              ),
              const Gap(Dimens.space8),
              Text(
                booking.serviceName,
                style: context.textTheme.bodyMedium,
              ),
              const Gap(Dimens.space4),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: Dimens.space12.r,
                    color: context.colorScheme.outline,
                  ),
                  const Gap.horizontal(Dimens.space4),
                  Text(schedule, style: context.textTheme.bodySmall),
                ],
              ),
              const Gap(Dimens.space4),
              Text(
                booking.bookingCode,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
