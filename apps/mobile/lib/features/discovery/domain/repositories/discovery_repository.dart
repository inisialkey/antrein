import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/discovery/domain/entities/business_detail.dart';
import 'package:antrein/features/discovery/domain/entities/business_summary.dart';
import 'package:antrein/features/discovery/domain/entities/service_item.dart';
import 'package:antrein/features/discovery/domain/entities/staff_member.dart';

abstract class DiscoveryRepository {
  ResultFuture<List<BusinessSummary>> listBusinesses({String? query});

  ResultFuture<BusinessDetail> getBusiness(String businessId);

  ResultFuture<List<ServiceItem>> listServices(String businessId);

  ResultFuture<List<StaffMember>> listStaff(
    String businessId, {
    String? serviceId,
  });
}
