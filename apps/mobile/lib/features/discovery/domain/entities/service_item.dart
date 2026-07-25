import 'package:antrein/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// A bookable service (api-contract §40).
class ServiceItem extends Equatable {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
    this.description,
    this.imageUrl,
    this.depositAmount,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int durationMinutes;
  final Money price;

  /// Fixed deposit required for the `deposit` payment option, when configured.
  final Money? depositAmount;
  final bool isActive;

  bool get supportsDeposit => (depositAmount?.amount ?? 0) > 0;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    imageUrl,
    durationMinutes,
    price,
    depositAmount,
    isActive,
  ];
}
