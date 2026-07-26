import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/reports/data/models/report_models.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class ReportRemoteDataSource {
  Future<DailySummaryModel> getDailySummary({
    required String businessId,
    required String outletId,
    String? date,
  });
}

@LazySingleton(as: ReportRemoteDataSource)
class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  const ReportRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<DailySummaryModel> getDailySummary({
    required String businessId,
    required String outletId,
    String? date,
  }) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.dailySummary(businessId),
        queryParameters: {'outletId': outletId, 'date': ?date},
      ),
    );
    return DailySummaryModel.fromJson((data as Map).cast<String, dynamic>());
  }
}
