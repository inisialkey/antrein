import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/service_management/domain/entities/managed_service.dart';

abstract class ServiceManagementRepository {
  /// Catalog including inactive services (§40 with `activeOnly=false`).
  ResultFuture<List<ManagedService>> listServices(String businessId);

  /// Active staff for the eligibility picker (§41).
  ResultFuture<List<StaffOption>> listStaffOptions(String businessId);

  /// §47. [idempotencyKey] is held across retries of one submission.
  ResultVoid createService(
    String businessId,
    ServiceDraft draft, {
    required String idempotencyKey,
  });

  /// §48.
  ResultVoid updateService(String businessId, ServiceDraft draft);

  /// §49 — deactivate, never delete: booking snapshots reference history.
  ResultVoid deactivateService(String businessId, String serviceId);
}
