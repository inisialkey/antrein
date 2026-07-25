import 'package:equatable/equatable.dart';

/// A bookable outlet of a business (api-contract §39 `outlets[]`).
class OutletInfo extends Equatable {
  const OutletInfo({
    required this.id,
    required this.name,
    this.address,
    this.phoneNumber,
  });

  final String id;
  final String name;
  final String? address;
  final String? phoneNumber;

  @override
  List<Object?> get props => [id, name, address, phoneNumber];
}

/// Business profile for the detail screen (api-contract §39).
class BusinessDetail extends Equatable {
  const BusinessDetail({
    required this.id,
    required this.name,
    required this.supportedPaymentOptions,
    required this.outlets,
    this.description,
    this.logoUrl,
    this.ratingAverage,
    this.ratingCount,
    this.cancellationPolicySummary,
  });

  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final double? ratingAverage;
  final int? ratingCount;
  final String? cancellationPolicySummary;
  final List<String> supportedPaymentOptions;
  final List<OutletInfo> outlets;

  OutletInfo? get primaryOutlet => outlets.isEmpty ? null : outlets.first;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    logoUrl,
    ratingAverage,
    ratingCount,
    cancellationPolicySummary,
    supportedPaymentOptions,
    outlets,
  ];
}
