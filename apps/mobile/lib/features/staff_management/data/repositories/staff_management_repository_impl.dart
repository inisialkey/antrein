import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/staff_management/data/datasources/staff_management_remote_data_source.dart';
import 'package:antrein/features/staff_management/domain/entities/managed_staff.dart';
import 'package:antrein/features/staff_management/domain/repositories/staff_management_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: StaffManagementRepository)
class StaffManagementRepositoryImpl implements StaffManagementRepository {
  const StaffManagementRepositoryImpl(this._remote);

  final StaffManagementRemoteDataSource _remote;

  @override
  ResultFuture<List<ManagedStaff>> listStaff(String businessId) async {
    try {
      final models = await _remote.listStaff(businessId);
      return Right(models.map((m) => m.toEntity()).toList(growable: false));
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'listStaff'));
    }
  }

  @override
  ResultFuture<String> inviteStaff(
    String businessId,
    StaffDraft draft, {
    required String idempotencyKey,
  }) async {
    try {
      final model = await _remote.inviteStaff(
        businessId,
        draft,
        idempotencyKey: idempotencyKey,
      );
      return Right(model.invitationId);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'inviteStaff'));
    }
  }

  @override
  ResultVoid updateStaff(String businessId, StaffDraft draft) async {
    try {
      await _remote.updateStaff(businessId, draft);
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'updateStaff'));
    }
  }

  @override
  ResultVoid deactivateStaff(String businessId, String staffId) async {
    try {
      await _remote.deactivateStaff(businessId, staffId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'deactivateStaff'));
    }
  }

  @override
  ResultVoid acceptInvitation(
    String invitationId, {
    required String idempotencyKey,
  }) async {
    try {
      await _remote.acceptInvitation(
        invitationId,
        idempotencyKey: idempotencyKey,
      );
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'acceptInvitation'));
    }
  }
}
