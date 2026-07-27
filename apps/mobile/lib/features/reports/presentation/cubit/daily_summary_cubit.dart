import 'package:antrein/features/reports/domain/entities/daily_summary.dart';
import 'package:antrein/features/reports/domain/usecases/get_daily_summary.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'daily_summary_state.dart';

/// Drives the business daily-summary screen (contract §98).
@injectable
class DailySummaryCubit extends Cubit<DailySummaryState> {
  DailySummaryCubit(this._getDailySummary) : super(const DailySummaryState());

  final GetDailySummary _getDailySummary;

  String? _businessId;
  String? _outletId;

  Future<void> load({
    required String businessId,
    required String outletId,
    String? date,
  }) async {
    _businessId = businessId;
    _outletId = outletId;
    // Fresh state per query — a date switch must not show the old day's data.
    emit(DailySummaryState(status: DailySummaryStatus.loading, date: date));
    final result = await _getDailySummary(
      GetDailySummaryParams(
        businessId: businessId,
        outletId: outletId,
        date: date,
      ),
    );
    result.match(
      (failure) => emit(
        state.copyWith(
          status: DailySummaryStatus.failure,
          message: failure.message,
        ),
      ),
      (summary) => emit(
        state.copyWith(status: DailySummaryStatus.success, summary: summary),
      ),
    );
  }

  /// Refetches the already-loaded outlet for [date] (`YYYY-MM-DD`, null =
  /// today). No-op before the first [load].
  Future<void> changeDate(String? date) async {
    final businessId = _businessId;
    final outletId = _outletId;
    if (businessId == null || outletId == null) return;
    await load(businessId: businessId, outletId: outletId, date: date);
  }
}
