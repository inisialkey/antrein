import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/reports/data/datasources/report_remote_data_source.dart';
import 'package:antrein/features/reports/domain/entities/daily_summary.dart';
import 'package:antrein/features/reports/domain/repositories/report_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ReportRepository)
class ReportRepositoryImpl implements ReportRepository {
  const ReportRepositoryImpl(this._remote);

  final ReportRemoteDataSource _remote;

  @override
  ResultFuture<DailySummary> getDailySummary({
    required String businessId,
    required String outletId,
    String? date,
  }) async {
    try {
      final model = await _remote.getDailySummary(
        businessId: businessId,
        outletId: outletId,
        date: date,
      );
      return Right(model.toEntity());
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'getDailySummary'));
    }
  }
}
