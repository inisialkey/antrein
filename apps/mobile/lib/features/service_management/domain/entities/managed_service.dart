import 'package:antrein/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// A service as its owner sees it (api-contract §47–§49): unlike the public
/// `ServiceItem`, inactive rows are included and staff eligibility is editable.
class ManagedService extends Equatable {
  const ManagedService({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
    this.description,
    this.depositValue = 0,
    this.eligibleStaffIds = const [],
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? description;
  final int durationMinutes;
  final Money price;

  /// Fixed deposit in IDR; `0` means the service takes no deposit (ADR 0022 —
  /// percentage deposits are out of MVP, so the type is implied by the value).
  final int depositValue;

  /// Empty = every staff member may perform it (backend rule).
  final List<String> eligibleStaffIds;
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    durationMinutes,
    price,
    depositValue,
    eligibleStaffIds,
    isActive,
  ];
}

/// Minimal staff row for the eligibility picker (api-contract §41).
class StaffOption extends Equatable {
  const StaffOption({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// What the form submits. A null [id] creates (§47), otherwise it updates (§48).
class ServiceDraft extends Equatable {
  const ServiceDraft({
    required this.name,
    required this.durationMinutes,
    required this.priceAmount,
    this.id,
    this.description,
    this.depositValue = 0,
    this.eligibleStaffIds = const [],
    this.isActive = true,
  });

  final String? id;
  final String name;
  final String? description;
  final int durationMinutes;
  final int priceAmount;
  final int depositValue;
  final List<String> eligibleStaffIds;
  final bool isActive;

  bool get isNew => id == null;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    durationMinutes,
    priceAmount,
    depositValue,
    eligibleStaffIds,
    isActive,
  ];
}
