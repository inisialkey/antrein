import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/reports/domain/entities/daily_summary.dart';

abstract class ReportRepository {
  /// Daily operational summary (§98). [date] is `YYYY-MM-DD`; null lets the
  /// backend default to today in Asia/Jakarta.
  ResultFuture<DailySummary> getDailySummary({
    required String businessId,
    required String outletId,
    String? date,
  });
}
