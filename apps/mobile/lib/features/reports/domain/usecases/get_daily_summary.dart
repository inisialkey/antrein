import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/reports/domain/entities/daily_summary.dart';
import 'package:antrein/features/reports/domain/repositories/report_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class GetDailySummary extends UseCase<DailySummary, GetDailySummaryParams> {
  const GetDailySummary(this._repository);

  final ReportRepository _repository;

  @override
  ResultFuture<DailySummary> call(GetDailySummaryParams params) =>
      _repository.getDailySummary(
        businessId: params.businessId,
        outletId: params.outletId,
        date: params.date,
      );
}

class GetDailySummaryParams extends Equatable {
  const GetDailySummaryParams({
    required this.businessId,
    required this.outletId,
    this.date,
  });

  final String businessId;
  final String outletId;
  final String? date;

  @override
  List<Object?> get props => [businessId, outletId, date];
}
