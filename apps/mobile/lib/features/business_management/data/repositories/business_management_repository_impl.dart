import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/business_management/data/datasources/business_management_remote_data_source.dart';
import 'package:antrein/features/business_management/domain/entities/managed_business.dart';
import 'package:antrein/features/business_management/domain/repositories/business_management_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: BusinessManagementRepository)
class BusinessManagementRepositoryImpl implements BusinessManagementRepository {
  const BusinessManagementRepositoryImpl(this._remote);

  final BusinessManagementRemoteDataSource _remote;

  @override
  ResultFuture<ManagedBusiness> getManagement(String businessId) async {
    try {
      final model = await _remote.getManagement(businessId);
      return Right(model.toEntity());
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'getManagement'));
    }
  }

  @override
  ResultVoid updateBusiness(
    String businessId,
    ManagedBusiness business,
  ) async {
    try {
      await _remote.updateBusiness(businessId, business);
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'updateBusiness'));
    }
  }

  @override
  ResultFuture<ManagedOutlet?> getOutlet(
    String businessId,
    String outletId,
  ) async {
    try {
      return Right(await _remote.getOutlet(businessId, outletId));
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'getOutlet'));
    }
  }

  @override
  ResultVoid updateOutlet(String businessId, ManagedOutlet outlet) async {
    try {
      await _remote.updateOutlet(businessId, outlet);
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'updateOutlet'));
    }
  }

  @override
  ResultVoid createBusiness({
    required String name,
    required String outletName,
    required String address,
    required String idempotencyKey,
    String? description,
    String? phoneNumber,
  }) async {
    try {
      await _remote.createBusiness(
        name: name,
        outletName: outletName,
        address: address,
        idempotencyKey: idempotencyKey,
        description: description,
        phoneNumber: phoneNumber,
      );
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'createBusiness'));
    }
  }
}
