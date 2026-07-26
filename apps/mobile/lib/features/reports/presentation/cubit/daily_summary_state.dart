part of 'daily_summary_cubit.dart';

enum DailySummaryStatus { initial, loading, success, failure }

class DailySummaryState extends Equatable {
  const DailySummaryState({
    this.status = DailySummaryStatus.initial,
    this.summary,
    this.message,
    this.date,
  });

  final DailySummaryStatus status;
  final DailySummary? summary;
  final String? message;

  /// Picked date (`YYYY-MM-DD`); null means the backend default (today).
  final String? date;

  DailySummaryState copyWith({
    DailySummaryStatus? status,
    DailySummary? summary,
    String? message,
  }) => DailySummaryState(
    status: status ?? this.status,
    summary: summary ?? this.summary,
    message: message ?? this.message,
    date: date,
  );

  @override
  List<Object?> get props => [status, summary, message, date];
}
