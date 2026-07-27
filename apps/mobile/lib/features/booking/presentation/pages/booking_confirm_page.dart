import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/booking/domain/entities/booking_draft.dart';
import 'package:antrein/features/booking/presentation/cubit/create_booking_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Step 3: review the draft, pick a payment option, submit (§60). On success
/// the flow lands on the booking detail — which doubles as the
/// payment-pending screen for online options.
class BookingConfirmPage extends StatefulWidget {
  const BookingConfirmPage({required this.draft, super.key});

  final BookingDraft draft;

  @override
  State<BookingConfirmPage> createState() => _BookingConfirmPageState();
}

class _BookingConfirmPageState extends State<BookingConfirmPage> {
  late String _paymentOption;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final options = widget.draft.availablePaymentOptions;
    _paymentOption = options.contains('pay_at_location')
        ? 'pay_at_location'
        : (options.isEmpty ? 'pay_at_location' : options.first);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _optionLabel(BuildContext context, String option) => switch (option) {
    'full_payment' => context.l10n.payFullOption,
    'deposit' => context.l10n.payDepositOption(
      widget.draft.service.depositAmount?.formatted ?? '',
    ),
    _ => context.l10n.payAtLocationOption,
  };

  String _errorText(BuildContext context, String message, String? code) =>
      switch (code) {
        ApiErrorCodes.bookingSlotUnavailable => context.l10n.slotTakenError,
        ApiErrorCodes.paymentProviderUnavailable =>
          context.l10n.providerUnavailableError,
        ApiErrorCodes.bookingActiveLimitReached =>
          context.l10n.activeLimitError,
        _ => message,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = widget.draft;
    final slot = draft.slot!;
    final locale = Localizations.localeOf(context).toString();
    final schedule = DateFormat(
      'EEEE, d MMMM yyyy · HH:mm',
      locale,
    ).format(slot.startsAt.toLocal());

    return BlocProvider(
      create: (_) => getIt<CreateBookingCubit>(),
      child: BlocConsumer<CreateBookingCubit, CreateBookingState>(
        listener: (context, state) {
          switch (state) {
            case CreateBookingSuccess(:final creation):
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.bookingCreated)),
              );
              context.goNamed(
                Routes.bookingDetail.name,
                pathParameters: {'bookingId': creation.booking.id},
              );
            case CreateBookingError(:final message, :final code):
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_errorText(context, message, code))),
              );
            default:
              break;
          }
        },
        builder: (context, state) => AppScaffold(
          appBar: AppBar(title: Text(l10n.confirmBookingTitle)),
          body: ListView(
            padding: EdgeInsets.all(Dimens.space16.r),
            children: [
              _SummaryCard(
                rows: [
                  (l10n.summaryBusiness, draft.businessName),
                  (l10n.summaryOutlet, draft.outlet.name),
                  (l10n.summaryService, draft.service.name),
                  (l10n.summaryStaff, draft.staff?.name ?? '-'),
                  (l10n.summarySchedule, schedule),
                  (
                    l10n.summaryDuration,
                    '${draft.service.durationMinutes} ${l10n.minutesShort}',
                  ),
                ],
              ),
              const Gap(Dimens.space16),
              Text(
                l10n.paymentMethodSection,
                style: context.textTheme.titleMedium,
              ),
              const Gap(Dimens.space8),
              RadioGroup<String>(
                groupValue: _paymentOption,
                onChanged: (value) =>
                    setState(() => _paymentOption = value ?? _paymentOption),
                child: Column(
                  children: [
                    for (final option in draft.availablePaymentOptions)
                      RadioListTile<String>(
                        value: option,
                        title: Text(_optionLabel(context, option)),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              const Gap(Dimens.space16),
              AppTextField(
                controller: _notesController,
                label: l10n.notesOptional,
                hint: l10n.notesHint,
              ),
              const Gap(Dimens.space24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.totalLabel, style: context.textTheme.titleMedium),
                  Text(
                    draft.service.price.formatted,
                    style: context.textTheme.titleLarge?.copyWith(
                      color: context.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (_paymentOption == 'deposit' &&
                  draft.service.depositAmount != null) ...[
                const Gap(Dimens.space4),
                Text(
                  l10n.payNowAmount(draft.service.depositAmount!.formatted),
                  style: context.textTheme.bodySmall,
                ),
              ],
              const Gap(Dimens.space24),
              AppButton(
                label: state is CreateBookingError && state.retryable
                    ? l10n.retryPayment
                    : l10n.confirmBookingAction,
                loading: state is CreateBookingSubmitting,
                onPressed: () => context.read<CreateBookingCubit>().submit(
                  draft.copyWith(
                    paymentOption: _paymentOption,
                    notes: _notesController.text.trim(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rows});

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
