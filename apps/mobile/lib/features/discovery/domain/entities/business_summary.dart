import 'package:antrein/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// A business card in the discovery list (api-contract §38).
class BusinessSummary extends Equatable {
  const BusinessSummary({
    required this.id,
    required this.name,
    required this.supportedPaymentOptions,
    this.logoUrl,
    this.ratingAverage,
    this.ratingCount,
    this.outletId,
    this.outletName,
    this.address,
    this.isOpenNow,
    this.minimumPrice,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final double? ratingAverage;
  final int? ratingCount;
  final String? outletId;
  final String? outletName;
  final String? address;
  final bool? isOpenNow;
  final Money? minimumPrice;
  final List<String> supportedPaymentOptions;

  @override
  List<Object?> get props => [
    id,
    name,
    logoUrl,
    ratingAverage,
    ratingCount,
    outletId,
    outletName,
    address,
    isOpenNow,
    minimumPrice,
    supportedPaymentOptions,
  ];
}
