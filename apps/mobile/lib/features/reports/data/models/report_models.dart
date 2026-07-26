import 'package:antrein/core/domain/money.dart';
import 'package:antrein/features/reports/domain/entities/daily_summary.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_models.freezed.dart';
part 'report_models.g.dart';

/// Wire model for the daily summary (§98). Counters default to 0 so a newer
/// backend dropping a bucket never crashes an older app.
@freezed
abstract class DailySummaryModel with _$DailySummaryModel {
  const DailySummaryModel._();

  const factory DailySummaryModel({
    required String date,
    required DailySummaryBookingsModel bookings,
    required DailySummaryQueueModel queue,
    required DailySummaryPaymentsModel payments,
  }) = _DailySummaryModel;

  factory DailySummaryModel.fromJson(Map<String, dynamic> json) =>
      _$DailySummaryModelFromJson(json);

  DailySummary toEntity() => DailySummary(
    date: date,
    totalBookings: bookings.total,
    confirmed: bookings.confirmed,
    waiting: bookings.waiting,
    inService: bookings.inService,
    completed: bookings.completed,
    cancelled: bookings.cancelled,
    noShow: bookings.noShow,
    queueActive: queue.active,
    averageWaitMinutes: queue.averageWaitMinutes,
    grossPaid: payments.grossPaid,
    pendingPayments: payments.pending,
    refunded: payments.refunded,
  );
}

@freezed
abstract class DailySummaryBookingsModel with _$DailySummaryBookingsModel {
  const factory DailySummaryBookingsModel({
    @Default(0) int total,
    @Default(0) int confirmed,
    @Default(0) int waiting,
    @Default(0) int inService,
    @Default(0) int completed,
    @Default(0) int cancelled,
    @Default(0) int noShow,
  }) = _DailySummaryBookingsModel;

  factory DailySummaryBookingsModel.fromJson(Map<String, dynamic> json) =>
      _$DailySummaryBookingsModelFromJson(json);
}

@freezed
abstract class DailySummaryQueueModel with _$DailySummaryQueueModel {
  const factory DailySummaryQueueModel({
    @Default(0) int active,
    @Default(0) int averageWaitMinutes,
  }) = _DailySummaryQueueModel;

  factory DailySummaryQueueModel.fromJson(Map<String, dynamic> json) =>
      _$DailySummaryQueueModelFromJson(json);
}

@freezed
abstract class DailySummaryPaymentsModel with _$DailySummaryPaymentsModel {
  const factory DailySummaryPaymentsModel({
    required Money grossPaid,
    required Money pending,
    required Money refunded,
  }) = _DailySummaryPaymentsModel;

  factory DailySummaryPaymentsModel.fromJson(Map<String, dynamic> json) =>
      _$DailySummaryPaymentsModelFromJson(json);
}
