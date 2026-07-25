import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/discovery/domain/entities/business_detail.dart';
import 'package:antrein/features/discovery/domain/entities/service_item.dart';
import 'package:antrein/features/discovery/domain/entities/staff_member.dart';
import 'package:antrein/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

/// Everything the business-detail screen needs: profile + services + staff,
/// fetched concurrently. First failure wins (the screen is all-or-nothing).
class BusinessProfile extends Equatable {
  const BusinessProfile({
    required this.detail,
    required this.services,
    required this.staff,
  });

  final BusinessDetail detail;
  final List<ServiceItem> services;
  final List<StaffMember> staff;

  @override
  List<Object?> get props => [detail, services, staff];
}

@injectable
class GetBusinessProfile
    extends UseCase<BusinessProfile, GetBusinessProfileParams> {
  const GetBusinessProfile(this._repository);

  final DiscoveryRepository _repository;

  @override
  ResultFuture<BusinessProfile> call(GetBusinessProfileParams params) async {
    final (detail, services, staff) = await (
      _repository.getBusiness(params.businessId),
      _repository.listServices(params.businessId),
      _repository.listStaff(params.businessId),
    ).wait;

    return detail.flatMap(
      (d) => services.flatMap(
        (s) => staff.map(
          (t) => BusinessProfile(detail: d, services: s, staff: t),
        ),
      ),
    );
  }
}

class GetBusinessProfileParams extends Equatable {
  const GetBusinessProfileParams({required this.businessId});

  final String businessId;

  @override
  List<Object?> get props => [businessId];
}
