import 'package:antrein/core/domain/money.dart';
import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/domain/entities/payment_info.dart';
import 'package:antrein/features/booking/domain/entities/slot.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'booking_models.freezed.dart';
part 'booking_models.g.dart';

/// Wire models for the booking APIs (api-contract §42, §59–§63, §69–§72).

@freezed
abstract class SlotModel with _$SlotModel {
  const SlotModel._();

  const factory SlotModel({
    required DateTime startsAt,
    required DateTime endsAt,
    required bool available,
  }) = _SlotModel;

  factory SlotModel.fromJson(Map<String, dynamic> json) =>
      _$SlotModelFromJson(json);

  Slot toEntity() =>
      Slot(startsAt: startsAt, endsAt: endsAt, available: available);
}

@freezed
abstract class NamedRefModel with _$NamedRefModel {
  const factory NamedRefModel({String? id, String? name}) = _NamedRefModel;

  factory NamedRefModel.fromJson(Map<String, dynamic> json) =>
      _$NamedRefModelFromJson(json);
}

@freezed
abstract class BookingOutletModel with _$BookingOutletModel {
  const factory BookingOutletModel({
    String? id,
    String? name,
    Map<String, dynamic>? address,
  }) = _BookingOutletModel;

  factory BookingOutletModel.fromJson(Map<String, dynamic> json) =>
      _$BookingOutletModelFromJson(json);
}

@freezed
abstract class BookingServiceModel with _$BookingServiceModel {
  const factory BookingServiceModel({
    String? id,
    String? name,
    int? durationMinutes,
    Money? price,
  }) = _BookingServiceModel;

  factory BookingServiceModel.fromJson(Map<String, dynamic> json) =>
      _$BookingServiceModelFromJson(json);
}

@freezed
abstract class PaymentSummaryModel with _$PaymentSummaryModel {
  const PaymentSummaryModel._();

  const factory PaymentSummaryModel({
    Money? totalAmount,
    Money? requiredNow,
    Money? paidAmount,
    Money? remainingAmount,
    String? status,
  }) = _PaymentSummaryModel;

  factory PaymentSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentSummaryModelFromJson(json);

  BookingPaymentSummary toEntity() => BookingPaymentSummary(
    totalAmount: totalAmount ?? const Money(0),
    requiredNow: requiredNow ?? const Money(0),
    paidAmount: paidAmount ?? const Money(0),
    remainingAmount: remainingAmount ?? const Money(0),
    status: status ?? 'unpaid',
  );
}

@freezed
abstract class CancellationModel with _$CancellationModel {
  const factory CancellationModel({
    @Default(false) bool canCancel,
    Money? refundEstimate,
    DateTime? deadlineAt,
  }) = _CancellationModel;

  factory CancellationModel.fromJson(Map<String, dynamic> json) =>
      _$CancellationModelFromJson(json);
}

@freezed
abstract class BookingModel with _$BookingModel {
  const BookingModel._();

  const factory BookingModel({
    required String id,
    required String bookingCode,
    required String status,
    required String paymentOption,
    NamedRefModel? business,
    BookingOutletModel? outlet,
    BookingServiceModel? service,
    NamedRefModel? staff,
    DateTime? scheduledAt,
    DateTime? expectedEndsAt,
    PaymentSummaryModel? paymentSummary,
    CancellationModel? cancellation,
    String? customerNotes,
    DateTime? createdAt,
  }) = _BookingModel;

  factory BookingModel.fromJson(Map<String, dynamic> json) =>
      _$BookingModelFromJson(json);

  Booking toEntity() => Booking(
    id: id,
    bookingCode: bookingCode,
    status: BookingStatus.fromWire(status),
    paymentOption: paymentOption,
    businessName: business?.name ?? '',
    outletName: outlet?.name ?? '',
    outletAddress: outlet?.address?['formatted'] as String?,
    serviceName: service?.name ?? '',
    servicePrice: service?.price ?? const Money(0),
    durationMinutes: service?.durationMinutes ?? 0,
    staffName: staff?.name,
    scheduledAt: scheduledAt,
    expectedEndsAt: expectedEndsAt,
    paymentSummary: paymentSummary?.toEntity(),
    canCancel: cancellation?.canCancel ?? false,
    refundEstimate: cancellation?.refundEstimate,
    cancellationDeadlineAt: cancellation?.deadlineAt,
    customerNotes: customerNotes,
    createdAt: createdAt,
  );
}

@freezed
abstract class CheckoutModel with _$CheckoutModel {
  const factory CheckoutModel({String? type, String? url}) = _CheckoutModel;

  factory CheckoutModel.fromJson(Map<String, dynamic> json) =>
      _$CheckoutModelFromJson(json);
}

@freezed
abstract class PaymentModel with _$PaymentModel {
  const PaymentModel._();

  const factory PaymentModel({
    required String id,
    required String status,
    String? bookingId,
    String? provider,
    Money? amount,
    CheckoutModel? checkout,
    DateTime? expiresAt,
    DateTime? paidAt,
  }) = _PaymentModel;

  factory PaymentModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentModelFromJson(json);

  PaymentInfo toEntity() => PaymentInfo(
    id: id,
    bookingId: bookingId ?? '',
    provider: provider ?? '',
    status: status,
    amount: amount ?? const Money(0),
    checkoutUrl: checkout?.url,
    expiresAt: expiresAt,
    paidAt: paidAt,
  );
}
