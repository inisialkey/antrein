import 'package:antrein/core/domain/money.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/domain/entities/booking_draft.dart';
import 'package:antrein/features/booking/domain/entities/slot.dart';
import 'package:antrein/features/booking/domain/repositories/booking_repository.dart';
import 'package:antrein/features/booking/domain/usecases/create_booking.dart';
import 'package:antrein/features/booking/presentation/cubit/create_booking_cubit.dart';
import 'package:antrein/features/discovery/domain/entities/business_detail.dart';
import 'package:antrein/features/discovery/domain/entities/service_item.dart';
import 'package:antrein/features/discovery/domain/entities/staff_member.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateBooking extends Mock implements CreateBooking {}

void main() {
  late MockCreateBooking createBooking;

  final draft = BookingDraft(
    businessId: 'biz_1',
    businessName: 'Barber One',
    outlet: const OutletInfo(id: 'out_1', name: 'Main'),
    service: const ServiceItem(
      id: 'svc_1',
      name: 'Haircut',
      durationMinutes: 45,
      price: Money(50000),
    ),
    supportedPaymentOptions: const ['pay_at_location', 'full_payment'],
    staff: const StaffMember(id: 'stf_1', name: 'Andi'),
    slot: Slot(
      startsAt: DateTime.utc(2026, 8, 1, 3),
      endsAt: DateTime.utc(2026, 8, 1, 3, 45),
      available: true,
    ),
  );

  const booking = Booking(
    id: 'bkg_1',
    bookingCode: 'ANT-20260801-0001',
    status: BookingStatus.confirmed,
    paymentOption: 'pay_at_location',
    businessName: 'Barber One',
    outletName: 'Main',
    serviceName: 'Haircut',
    servicePrice: Money(50000),
    durationMinutes: 45,
  );

  setUpAll(() {
    registerFallbackValue(
      CreateBookingParams(
        businessId: '',
        outletId: '',
        serviceId: '',
        staffId: '',
        scheduledAt: DateTime.utc(2026),
        paymentOption: 'pay_at_location',
        idempotencyKey: '',
      ),
    );
  });

  setUp(() {
    createBooking = MockCreateBooking();
  });

  CreateBookingCubit build() => CreateBookingCubit(createBooking);

  blocTest<CreateBookingCubit, CreateBookingState>(
    'emits submitting then success and forwards the draft fields',
    build: build,
    setUp: () => when(() => createBooking(any())).thenAnswer(
      (_) async => const Right(BookingCreation(booking: booking)),
    ),
    act: (cubit) => cubit.submit(draft),
    expect: () => [
      const CreateBookingState.submitting(),
      const CreateBookingState.success(BookingCreation(booking: booking)),
    ],
    verify: (_) {
      final params =
          verify(() => createBooking(captureAny())).captured.single
              as CreateBookingParams;
      expect(params.businessId, 'biz_1');
      expect(params.staffId, 'stf_1');
      expect(params.scheduledAt, DateTime.utc(2026, 8, 1, 3));
      expect(params.idempotencyKey, isNotEmpty);
    },
  );

  blocTest<CreateBookingCubit, CreateBookingState>(
    'keeps the same idempotency key across a provider-outage retry (ADR 0040)',
    build: build,
    setUp: () {
      final answers = <Either<Failure, BookingCreation>>[
        const Left(
          ServerFailure(
            'Provider down.',
            code: 'PAYMENT_PROVIDER_UNAVAILABLE',
          ),
        ),
        const Right(BookingCreation(booking: booking)),
      ];
      when(
        () => createBooking(any()),
      ).thenAnswer((_) async => answers.removeAt(0));
    },
    act: (cubit) async {
      await cubit.submit(draft);
      await cubit.submit(draft);
    },
    expect: () => [
      const CreateBookingState.submitting(),
      const CreateBookingState.error(
        'Provider down.',
        code: 'PAYMENT_PROVIDER_UNAVAILABLE',
        retryable: true,
      ),
      const CreateBookingState.submitting(),
      const CreateBookingState.success(BookingCreation(booking: booking)),
    ],
    verify: (_) {
      final captured = verify(
        () => createBooking(captureAny()),
      ).captured.cast<CreateBookingParams>();
      expect(captured, hasLength(2));
      expect(captured[0].idempotencyKey, captured[1].idempotencyKey);
    },
  );

  blocTest<CreateBookingCubit, CreateBookingState>(
    'rotates the key after a definitive rejection',
    build: build,
    setUp: () {
      final answers = <Either<Failure, BookingCreation>>[
        const Left(
          ConflictFailure('Slot taken.', code: 'BOOKING_SLOT_UNAVAILABLE'),
        ),
        const Right(BookingCreation(booking: booking)),
      ];
      when(
        () => createBooking(any()),
      ).thenAnswer((_) async => answers.removeAt(0));
    },
    act: (cubit) async {
      await cubit.submit(draft);
      await cubit.submit(draft);
    },
    verify: (_) {
      final captured = verify(
        () => createBooking(captureAny()),
      ).captured.cast<CreateBookingParams>();
      expect(captured[0].idempotencyKey, isNot(captured[1].idempotencyKey));
    },
  );

  blocTest<CreateBookingCubit, CreateBookingState>(
    'does nothing without a selected slot',
    build: build,
    act: (cubit) => cubit.submit(
      BookingDraft(
        businessId: draft.businessId,
        businessName: draft.businessName,
        outlet: draft.outlet,
        service: draft.service,
        supportedPaymentOptions: draft.supportedPaymentOptions,
      ),
    ),
    expect: () => <CreateBookingState>[],
    verify: (_) => verifyNever(() => createBooking(any())),
  );
}
