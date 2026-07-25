import 'package:antrein/features/booking/domain/entities/slot.dart';
import 'package:antrein/features/discovery/domain/entities/business_detail.dart';
import 'package:antrein/features/discovery/domain/entities/service_item.dart';
import 'package:antrein/features/discovery/domain/entities/staff_member.dart';
import 'package:equatable/equatable.dart';

/// In-flight booking selection carried through the flow
/// (business detail → slot picker → confirmation). Immutable; each step
/// produces a copy with more fields filled.
class BookingDraft extends Equatable {
  const BookingDraft({
    required this.businessId,
    required this.businessName,
    required this.outlet,
    required this.service,
    required this.supportedPaymentOptions,
    this.staff,
    this.slot,
    this.paymentOption = 'pay_at_location',
    this.notes,
  });

  final String businessId;
  final String businessName;
  final OutletInfo outlet;
  final ServiceItem service;
  final List<String> supportedPaymentOptions;
  final StaffMember? staff;
  final Slot? slot;
  final String paymentOption;
  final String? notes;

  BookingDraft copyWith({
    StaffMember? staff,
    Slot? slot,
    String? paymentOption,
    String? notes,
  }) => BookingDraft(
    businessId: businessId,
    businessName: businessName,
    outlet: outlet,
    service: service,
    supportedPaymentOptions: supportedPaymentOptions,
    staff: staff ?? this.staff,
    slot: slot ?? this.slot,
    paymentOption: paymentOption ?? this.paymentOption,
    notes: notes ?? this.notes,
  );

  /// Payment options this draft can actually use: intersects the business
  /// policy with service configuration (deposit needs a configured amount).
  List<String> get availablePaymentOptions => supportedPaymentOptions
      .where((o) => o != 'deposit' || service.supportsDeposit)
      .toList(growable: false);

  @override
  List<Object?> get props => [
    businessId,
    businessName,
    outlet,
    service,
    supportedPaymentOptions,
    staff,
    slot,
    paymentOption,
    notes,
  ];
}
