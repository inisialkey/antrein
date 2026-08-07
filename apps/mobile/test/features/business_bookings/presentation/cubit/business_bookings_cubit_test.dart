import 'package:antrein/core/domain/money.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/features/booking/booking.dart';
import 'package:antrein/features/business_bookings/domain/repositories/business_bookings_repository.dart';
import 'package:antrein/features/business_bookings/presentation/cubit/business_bookings_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockBusinessBookingsRepository extends Mock
    implements BusinessBookingsRepository {}

void main() {
  late MockBusinessBookingsRepository repo;

  Booking booking({int remaining = 25000, String id = 'bkg_1'}) => Booking(
    id: id,
    bookingCode: 'ANT-20260806-0001',
    status: BookingStatus.confirmed,
    paymentOption: 'pay_at_location',
    businessName: 'Barbershop',
    outletName: 'Outlet',
    serviceName: 'Potong rambut',
    servicePrice: const Money(50000),
    durationMinutes: 30,
    paymentSummary: BookingPaymentSummary(
      totalAmount: const Money(50000),
      requiredNow: const Money(0),
      paidAmount: Money(50000 - remaining),
      remainingAmount: Money(remaining),
      status: remaining == 0 ? 'paid' : 'partially_paid',
    ),
  );

  setUp(() {
    repo = MockBusinessBookingsRepository();
    registerFallbackValue(const Money(0));
    when(
      () => repo.list(
        businessId: any(named: 'businessId'),
        outletId: any(named: 'outletId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => Right([booking()]));
  });

  BusinessBookingsCubit build() => BusinessBookingsCubit(repo);

  Future<void> loaded(BusinessBookingsCubit cubit) =>
      cubit.load(businessId: 'biz_1', outletId: 'out_1');

  group('load (§65)', () {
    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'lists the outlet-day and reports success',
      build: build,
      act: loaded,
      verify: (cubit) {
        expect(cubit.state.status, BookingDeskStatus.success);
        expect(cubit.state.bookings, hasLength(1));
      },
    );

    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'an empty day is empty, not a failure',
      build: build,
      setUp: () => when(
        () => repo.list(
          businessId: any(named: 'businessId'),
          outletId: any(named: 'outletId'),
          date: any(named: 'date'),
        ),
      ).thenAnswer((_) async => const Right([])),
      act: loaded,
      verify: (cubit) => expect(cubit.state.status, BookingDeskStatus.empty),
    );
  });

  group('pay-at-location confirmation (§73)', () {
    setUp(
      () => when(
        () => repo.confirmPayAtLocation(
          businessId: any(named: 'businessId'),
          bookingId: any(named: 'bookingId'),
          amount: any(named: 'amount'),
          method: any(named: 'method'),
          idempotencyKey: any(named: 'idempotencyKey'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => const Right(null)),
    );

    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'sends the outstanding balance, never a typed figure',
      build: build,
      act: (cubit) async {
        await loaded(cubit);
        await cubit.confirmPayment(
          booking: booking(remaining: 30000),
          method: 'cash',
        );
      },
      verify: (cubit) {
        final sent =
            verify(
                  () => repo.confirmPayAtLocation(
                    businessId: 'biz_1',
                    bookingId: 'bkg_1',
                    amount: captureAny(named: 'amount'),
                    method: 'cash',
                    idempotencyKey: any(named: 'idempotencyKey'),
                    note: any(named: 'note'),
                  ),
                ).captured.single
                as Money;
        expect(sent, const Money(30000));
        expect(cubit.state.actionDone, BookingDeskAction.paymentConfirmed);
      },
    );

    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'a stale outstanding figure resyncs the list before the next attempt',
      build: build,
      setUp: () =>
          when(
            () => repo.confirmPayAtLocation(
              businessId: any(named: 'businessId'),
              bookingId: any(named: 'bookingId'),
              amount: any(named: 'amount'),
              method: any(named: 'method'),
              idempotencyKey: any(named: 'idempotencyKey'),
              note: any(named: 'note'),
            ),
          ).thenAnswer(
            (_) async => const Left(
              ConflictFailure(
                'Amount mismatch.',
                code: ApiErrorCodes.paymentAmountMismatch,
              ),
            ),
          ),
      act: (cubit) async {
        await loaded(cubit);
        await cubit.confirmPayment(booking: booking(), method: 'cash');
      },
      verify: (cubit) {
        expect(cubit.state.actionError, 'Amount mismatch.');
        expect(cubit.state.actionDone, isNull);
        // Initial load + the post-rejection resync.
        verify(
          () => repo.list(
            businessId: any(named: 'businessId'),
            outletId: any(named: 'outletId'),
            date: any(named: 'date'),
          ),
        ).called(2);
      },
    );

    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'reuses the key across a transport retry, rotates after a coded one',
      build: build,
      setUp: () {
        var call = 0;
        when(
          () => repo.confirmPayAtLocation(
            businessId: any(named: 'businessId'),
            bookingId: any(named: 'bookingId'),
            amount: any(named: 'amount'),
            method: any(named: 'method'),
            idempotencyKey: any(named: 'idempotencyKey'),
            note: any(named: 'note'),
          ),
        ).thenAnswer((_) async {
          call++;
          // 1st: transport failure (no code) — same key must be replayed.
          // 2nd: coded rejection — the key is burnt, so the 3rd differs.
          if (call == 1) return const Left(NetworkFailure('offline'));
          if (call == 2) {
            return const Left(
              ConflictFailure('nope', code: ApiErrorCodes.validationFailed),
            );
          }
          return const Right(null);
        });
      },
      act: (cubit) async {
        await loaded(cubit);
        for (var i = 0; i < 3; i++) {
          await cubit.confirmPayment(booking: booking(), method: 'cash');
        }
      },
      verify: (_) {
        final keys = verify(
          () => repo.confirmPayAtLocation(
            businessId: any(named: 'businessId'),
            bookingId: any(named: 'bookingId'),
            amount: any(named: 'amount'),
            method: any(named: 'method'),
            idempotencyKey: captureAny(named: 'idempotencyKey'),
            note: any(named: 'note'),
          ),
        ).captured.cast<String>();
        expect(keys[0], keys[1], reason: 'transport retry replays the key');
        expect(keys[2], isNot(keys[1]), reason: 'coded rejection burns it');
      },
    );
  });

  group('cancel (§68.1) and no-show (§68)', () {
    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'cancel sends both required fields and resyncs',
      build: build,
      setUp: () => when(
        () => repo.cancel(
          businessId: any(named: 'businessId'),
          bookingId: any(named: 'bookingId'),
          reasonCode: any(named: 'reasonCode'),
          reason: any(named: 'reason'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => const Right(null)),
      act: (cubit) async {
        await loaded(cubit);
        await cubit.cancelBooking(
          booking: booking(),
          reasonCode: 'business_unavailable',
          reason: 'Barber sakit',
        );
      },
      verify: (cubit) {
        verify(
          () => repo.cancel(
            businessId: 'biz_1',
            bookingId: 'bkg_1',
            reasonCode: 'business_unavailable',
            reason: 'Barber sakit',
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).called(1);
        expect(cubit.state.actionDone, BookingDeskAction.cancelled);
      },
    );

    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'a second action is refused while one is in flight',
      build: build,
      setUp: () =>
          when(
            () => repo.markNoShow(
              businessId: any(named: 'businessId'),
              bookingId: any(named: 'bookingId'),
              idempotencyKey: any(named: 'idempotencyKey'),
              reason: any(named: 'reason'),
            ),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return const Right(null);
          }),
      act: (cubit) async {
        await loaded(cubit);
        final first = cubit.markNoShow(booking: booking());
        await cubit.markNoShow(booking: booking(id: 'bkg_2'));
        await first;
      },
      verify: (_) => verify(
        () => repo.markNoShow(
          businessId: any(named: 'businessId'),
          bookingId: any(named: 'bookingId'),
          idempotencyKey: any(named: 'idempotencyKey'),
          reason: any(named: 'reason'),
        ),
      ).called(1),
    );
  });

  group('refund (§70 + §74)', () {
    PaymentInfo payment({
      String id = 'pay_1',
      String provider = 'sandbox',
      String status = 'paid',
    }) => PaymentInfo(
      id: id,
      bookingId: 'bkg_1',
      provider: provider,
      status: status,
      amount: const Money(50000),
    );

    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'picks the online payment and ignores the counter one',
      build: build,
      setUp: () => when(() => repo.listPayments(any())).thenAnswer(
        (_) async => Right([
          payment(id: 'pay_pal', provider: 'pay_at_location'),
          payment(id: 'pay_online'),
        ]),
      ),
      act: (cubit) async {
        await loaded(cubit);
        await cubit.loadRefundable('bkg_1');
      },
      verify: (cubit) {
        expect(cubit.state.refundable?.id, 'pay_online');
        expect(cubit.state.isLoadingRefundable, isFalse);
      },
    );

    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'leaves nothing refundable when only counter money was taken',
      build: build,
      setUp: () => when(() => repo.listPayments(any())).thenAnswer(
        (_) async =>
            Right([payment(id: 'pay_pal', provider: 'pay_at_location')]),
      ),
      act: (cubit) async {
        await loaded(cubit);
        await cubit.loadRefundable('bkg_1');
      },
      verify: (cubit) => expect(cubit.state.refundable, isNull),
    );

    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'refunds the payment in full and resyncs the day',
      build: build,
      setUp: () {
        when(() => repo.listPayments(any())).thenAnswer(
          (_) async => Right([payment()]),
        );
        when(
          () => repo.requestRefund(
            businessId: any(named: 'businessId'),
            paymentId: any(named: 'paymentId'),
            amount: any(named: 'amount'),
            reasonCode: any(named: 'reasonCode'),
            reason: any(named: 'reason'),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async => const Right(null));
      },
      act: (cubit) async {
        await loaded(cubit);
        await cubit.refund(
          booking: booking(),
          payment: payment(),
          reason: 'Barber tidak hadir',
        );
      },
      verify: (cubit) {
        verify(
          () => repo.requestRefund(
            businessId: 'biz_1',
            paymentId: 'pay_1',
            amount: const Money(50000),
            reasonCode: 'business_requested',
            reason: 'Barber tidak hadir',
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).called(1);
        expect(cubit.state.actionDone, BookingDeskAction.refunded);
        // Two list reads: the initial load plus the post-refund resync.
        verify(
          () => repo.list(
            businessId: any(named: 'businessId'),
            outletId: any(named: 'outletId'),
            date: any(named: 'date'),
          ),
        ).called(2);
      },
    );

    blocTest<BusinessBookingsCubit, BusinessBookingsState>(
      'surfaces a rejected refund without marking it done',
      build: build,
      setUp: () {
        when(() => repo.listPayments(any())).thenAnswer(
          (_) async => Right([payment()]),
        );
        when(
          () => repo.requestRefund(
            businessId: any(named: 'businessId'),
            paymentId: any(named: 'paymentId'),
            amount: any(named: 'amount'),
            reasonCode: any(named: 'reasonCode'),
            reason: any(named: 'reason'),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer(
          (_) async => const Left(
            ServerFailure(
              'Refund sudah diproses.',
              code: ApiErrorCodes.refundAlreadyPending,
            ),
          ),
        );
      },
      act: (cubit) async {
        await loaded(cubit);
        await cubit.refund(
          booking: booking(),
          payment: payment(),
          reason: 'Dobel bayar',
        );
      },
      verify: (cubit) {
        expect(cubit.state.actionDone, isNull);
        expect(cubit.state.actionError, 'Refund sudah diproses.');
      },
    );
  });
}
