import 'package:antrein/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// Wire statuses per product brief §16. Unknown values map to [unknown] so a
/// newer backend never crashes an older app.
enum BookingStatus {
  pendingPayment('pending_payment'),
  confirmed('confirmed'),
  checkedIn('checked_in'),
  waiting('waiting'),
  called('called'),
  inService('in_service'),
  completed('completed'),
  cancelled('cancelled'),
  expired('expired'),
  noShow('no_show'),
  unknown('unknown');

  const BookingStatus(this.wire);

  final String wire;

  static BookingStatus fromWire(String? value) => BookingStatus.values
      .firstWhere((s) => s.wire == value, orElse: () => BookingStatus.unknown);
}

class BookingPaymentSummary extends Equatable {
  const BookingPaymentSummary({
    required this.totalAmount,
    required this.requiredNow,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
  });

  final Money totalAmount;
  final Money requiredNow;
  final Money paidAmount;
  final Money remainingAmount;

  /// unpaid | partially_paid | paid | overpaid
  final String status;

  @override
  List<Object?> get props => [
    totalAmount,
    requiredNow,
    paidAmount,
    remainingAmount,
    status,
  ];
}

/// Customer-facing booking (api-contract §59).
class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.bookingCode,
    required this.status,
    required this.paymentOption,
    required this.businessName,
    required this.outletName,
    required this.serviceName,
    required this.servicePrice,
    required this.durationMinutes,
    this.outletAddress,
    this.staffName,
    this.scheduledAt,
    this.expectedEndsAt,
    this.paymentSummary,
    this.canCancel = false,
    this.refundEstimate,
    this.cancellationDeadlineAt,
    this.customerNotes,
    this.createdAt,
    this.customerName,
    this.customerPhone,
    this.internalNotes,
    this.isWalkIn = false,
  });

  final String id;
  final String bookingCode;
  final BookingStatus status;
  final String paymentOption;
  final String businessName;
  final String outletName;
  final String? outletAddress;
  final String serviceName;
  final Money servicePrice;
  final int durationMinutes;
  final String? staffName;
  final DateTime? scheduledAt;
  final DateTime? expectedEndsAt;
  final BookingPaymentSummary? paymentSummary;
  final bool canCancel;
  final Money? refundEstimate;
  final DateTime? cancellationDeadlineAt;
  final String? customerNotes;
  final DateTime? createdAt;

  /// Business view only (§65/§66) — null on the customer's own reads.
  final String? customerName;
  final String? customerPhone;
  final String? internalNotes;
  final bool isWalkIn;

  bool get isAwaitingPayment => status == BookingStatus.pendingPayment;

  /// Money still owed at the counter — what §73 confirmation must send.
  Money get outstanding => paymentSummary?.remainingAmount ?? const Money(0);

  @override
  List<Object?> get props => [
    id,
    bookingCode,
    status,
    paymentOption,
    businessName,
    outletName,
    outletAddress,
    serviceName,
    servicePrice,
    durationMinutes,
    staffName,
    scheduledAt,
    expectedEndsAt,
    paymentSummary,
    canCancel,
    refundEstimate,
    cancellationDeadlineAt,
    customerNotes,
    createdAt,
    customerName,
    customerPhone,
    internalNotes,
    isWalkIn,
  ];
}
