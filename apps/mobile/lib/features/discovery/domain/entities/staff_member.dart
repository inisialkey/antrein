import 'package:equatable/equatable.dart';

/// A bookable staff member (api-contract §41).
class StaffMember extends Equatable {
  const StaffMember({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.ratingAverage,
    this.eligibleServiceIds = const [],
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final double? ratingAverage;
  final List<String> eligibleServiceIds;
  final bool isActive;

  /// Empty eligibility list = eligible for every service (backend rule).
  bool canPerform(String serviceId) =>
      eligibleServiceIds.isEmpty || eligibleServiceIds.contains(serviceId);

  @override
  List<Object?> get props => [
    id,
    name,
    avatarUrl,
    ratingAverage,
    eligibleServiceIds,
    isActive,
  ];
}
