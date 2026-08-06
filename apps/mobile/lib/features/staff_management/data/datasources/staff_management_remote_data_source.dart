import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/staff_management/data/models/managed_staff_models.dart';
import 'package:antrein/features/staff_management/domain/entities/managed_staff.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class StaffManagementRemoteDataSource {
  Future<List<ManagedStaffModel>> listStaff(String businessId);

  Future<StaffInvitationModel> inviteStaff(
    String businessId,
    StaffDraft draft, {
    required String idempotencyKey,
  });

  Future<void> updateStaff(String businessId, StaffDraft draft);

  Future<void> deactivateStaff(String businessId, String staffId);

  Future<void> acceptInvitation(
    String invitationId, {
    required String idempotencyKey,
  });
}

@LazySingleton(as: StaffManagementRemoteDataSource)
class StaffManagementRemoteDataSourceImpl
    implements StaffManagementRemoteDataSource {
  const StaffManagementRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<ManagedStaffModel>> listStaff(String businessId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.businessStaff(businessId),
        // Inactive members stay visible so the owner can see who was removed.
        queryParameters: {'activeOnly': false, 'limit': 100},
      ),
    );
    return ((data['items'] as List<dynamic>?) ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => ManagedStaffModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<StaffInvitationModel> inviteStaff(
    String businessId,
    StaffDraft draft, {
    required String idempotencyKey,
  }) async {
    final data = await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.staffInvitations(businessId),
        data: {
          'email': draft.email,
          'displayName': draft.displayName,
          'role': draft.role.wire,
          'outletIds': draft.outletIds,
          'eligibleServiceIds': draft.eligibleServiceIds,
          // `permissions` omitted on purpose: the backend applies the role
          // preset (§128), which is what the form offers.
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      ),
    );
    return StaffInvitationModel.fromJson(data);
  }

  @override
  Future<void> updateStaff(String businessId, StaffDraft draft) => sendEnvelope(
    () => _dio.patch<dynamic>(
      ApiEndpoints.staffDetail(businessId, draft.id!),
      data: {
        'displayName': draft.displayName,
        'role': draft.role.wire,
        'eligibleServiceIds': draft.eligibleServiceIds,
        'isActive': draft.isActive,
      },
    ),
  );

  @override
  Future<void> deactivateStaff(String businessId, String staffId) =>
      sendEnvelope(
        () => _dio.post<dynamic>(
          ApiEndpoints.staffDeactivate(businessId, staffId),
        ),
      );

  @override
  Future<void> acceptInvitation(
    String invitationId, {
    required String idempotencyKey,
  }) => sendEnvelope(
    () => _dio.post<dynamic>(
      ApiEndpoints.staffInvitationAccept(invitationId),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
  );
}
