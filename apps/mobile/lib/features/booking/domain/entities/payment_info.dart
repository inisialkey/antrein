import 'package:antrein/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// A payment attempt on a booking (api-contract §60/§69). The checkout link is
/// only present on freshly created online payments.
class PaymentInfo extends Equatable {
  const PaymentInfo({
    required this.id,
    required this.bookingId,
    required this.provider,
    required this.status,
    required this.amount,
    this.checkoutUrl,
    this.expiresAt,
    this.paidAt,
  });

  final String id;
  final String bookingId;
  final String provider;

  /// pending | paid | failed | expired | cancelled | refund_* (wire values)
  final String status;
  final Money amount;
  final String? checkoutUrl;
  final DateTime? expiresAt;
  final DateTime? paidAt;

  bool get isPending => status == 'pending';

  @override
  List<Object?> get props => [
    id,
    bookingId,
    provider,
    status,
    amount,
    checkoutUrl,
    expiresAt,
    paidAt,
  ];
}
