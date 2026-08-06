import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/service_management/data/datasources/service_management_remote_data_source.dart';
import 'package:antrein/features/service_management/domain/entities/managed_service.dart';
import 'package:antrein/features/service_management/domain/repositories/service_management_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ServiceManagementRepository)
class ServiceManagementRepositoryImpl implements ServiceManagementRepository {
  const ServiceManagementRepositoryImpl(this._remote);

  final ServiceManagementRemoteDataSource _remote;

  @override
  ResultFuture<List<ManagedService>> listServices(String businessId) async {
    try {
      final models = await _remote.listServices(businessId);
      return Right(models.map((m) => m.toEntity()).toList(growable: false));
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'listServices'));
    }
  }

  @override
  ResultFuture<List<StaffOption>> listStaffOptions(String businessId) async {
    try {
      final models = await _remote.listStaffOptions(businessId);
      return Right(models.map((m) => m.toEntity()).toList(growable: false));
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'listStaffOptions'));
    }
  }

  @override
  ResultVoid createService(
    String businessId,
    ServiceDraft draft, {
    required String idempotencyKey,
  }) async {
    try {
      await _remote.createService(
        businessId,
        draft,
        idempotencyKey: idempotencyKey,
      );
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'createService'));
    }
  }

  @override
  ResultVoid updateService(String businessId, ServiceDraft draft) async {
    try {
      await _remote.updateService(businessId, draft);
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'updateService'));
    }
  }

  @override
  ResultVoid deactivateService(String businessId, String serviceId) async {
    try {
      await _remote.deactivateService(businessId, serviceId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'deactivateService'));
    }
  }
}
