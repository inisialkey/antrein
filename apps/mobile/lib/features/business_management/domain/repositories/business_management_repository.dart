import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/business_management/domain/entities/managed_business.dart';

abstract class BusinessManagementRepository {
  /// §44.
  ResultFuture<ManagedBusiness> getManagement(String businessId);

  /// §45.
  ResultVoid updateBusiness(String businessId, ManagedBusiness business);

  /// Current outlet values, read from the public §39 detail — there is no
  /// management read for a single outlet. Null when the id is not on the
  /// business.
  ResultFuture<ManagedOutlet?> getOutlet(String businessId, String outletId);

  /// §46.
  ResultVoid updateOutlet(String businessId, ManagedOutlet outlet);

  /// §43 — one owned business per user (`BUSINESS_LIMIT_REACHED`, ADR 0026).
  ResultVoid createBusiness({
    required String name,
    required String outletName,
    required String address,
    required String idempotencyKey,
    String? description,
    String? phoneNumber,
  });
}
