import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/service_management/data/models/managed_service_models.dart';
import 'package:antrein/features/service_management/domain/entities/managed_service.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class ServiceManagementRemoteDataSource {
  Future<List<ManagedServiceModel>> listServices(String businessId);

  Future<List<StaffOptionModel>> listStaffOptions(String businessId);

  Future<void> createService(
    String businessId,
    ServiceDraft draft, {
    required String idempotencyKey,
  });

  Future<void> updateService(String businessId, ServiceDraft draft);

  Future<void> deactivateService(String businessId, String serviceId);
}

@LazySingleton(as: ServiceManagementRemoteDataSource)
class ServiceManagementRemoteDataSourceImpl
    implements ServiceManagementRemoteDataSource {
  const ServiceManagementRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<ManagedServiceModel>> listServices(String businessId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.businessServices(businessId),
        // Management lists inactive services too — that is the only difference
        // from the public §40 read.
        queryParameters: {'activeOnly': false, 'limit': 100},
      ),
    );
    return _items(data).map(ManagedServiceModel.fromJson).toList();
  }

  /// ponytail: the service form needs staff names, and `staff_management`
  /// already depends on this feature for its own picker — reading §41 here
  /// keeps that dependency one-way instead of making the two features cyclic.
  @override
  Future<List<StaffOptionModel>> listStaffOptions(String businessId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.businessStaff(businessId),
        queryParameters: {'activeOnly': true, 'limit': 100},
      ),
    );
    return _items(data).map(StaffOptionModel.fromJson).toList();
  }

  @override
  Future<void> createService(
    String businessId,
    ServiceDraft draft, {
    required String idempotencyKey,
  }) => sendEnvelope(
    () => _dio.post<dynamic>(
      ApiEndpoints.businessServices(businessId),
      data: _body(draft),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
  );

  @override
  Future<void> updateService(String businessId, ServiceDraft draft) =>
      sendEnvelope(
        () => _dio.patch<dynamic>(
          ApiEndpoints.serviceDetail(businessId, draft.id!),
          data: _body(draft),
        ),
      );

  @override
  Future<void> deactivateService(String businessId, String serviceId) =>
      sendEnvelope(
        () => _dio.post<dynamic>(
          ApiEndpoints.serviceDeactivate(businessId, serviceId),
        ),
      );

  /// §47 and §48 take the same fields; PATCH treats an explicit null as "clear".
  Map<String, dynamic> _body(ServiceDraft draft) => {
    'name': draft.name,
    'description': draft.description,
    // Omitted rather than null: a null would clear a photo the form never
    // touched, and PATCH treats an absent key as "leave it".
    if (draft.imageFileId != null) 'imageFileId': draft.imageFileId,
    'durationMinutes': draft.durationMinutes,
    'price': {'amount': draft.priceAmount, 'currency': 'IDR'},
    'deposit': draft.depositValue > 0
        ? {'type': 'fixed', 'value': draft.depositValue}
        : {'type': 'none', 'value': 0},
    'eligibleStaffIds': draft.eligibleStaffIds,
    'isActive': draft.isActive,
  };

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) =>
      ((data['items'] as List<dynamic>?) ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
}
