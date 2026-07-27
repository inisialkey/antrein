import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/discovery/data/datasources/discovery_remote_data_source.dart';
import 'package:antrein/features/discovery/domain/entities/business_detail.dart';
import 'package:antrein/features/discovery/domain/entities/business_summary.dart';
import 'package:antrein/features/discovery/domain/entities/service_item.dart';
import 'package:antrein/features/discovery/domain/entities/staff_member.dart';
import 'package:antrein/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DiscoveryRepository)
class DiscoveryRepositoryImpl implements DiscoveryRepository {
  const DiscoveryRepositoryImpl(this._remote);

  final DiscoveryRemoteDataSource _remote;

  @override
  ResultFuture<List<BusinessSummary>> listBusinesses({String? query}) =>
      _guard('listBusinesses', () async {
        final models = await _remote.listBusinesses(query: query);
        return models.map((m) => m.toEntity()).toList(growable: false);
      });

  @override
  ResultFuture<BusinessDetail> getBusiness(String businessId) =>
      _guard('getBusiness', () async {
        final model = await _remote.getBusiness(businessId);
        return model.toEntity();
      });

  @override
  ResultFuture<List<ServiceItem>> listServices(String businessId) =>
      _guard('listServices', () async {
        final models = await _remote.listServices(businessId);
        return models.map((m) => m.toEntity()).toList(growable: false);
      });

  @override
  ResultFuture<List<StaffMember>> listStaff(
    String businessId, {
    String? serviceId,
  }) => _guard('listStaff', () async {
    final models = await _remote.listStaff(businessId, serviceId: serviceId);
    return models.map((m) => m.toEntity()).toList(growable: false);
  });

  Future<Either<Failure, T>> _guard<T>(
    String label,
    Future<T> Function() action,
  ) async {
    try {
      return Right(await action());
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, label));
    }
  }
}
