import 'package:antrein/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// One outlet-day operational summary (contract §98), flattened for the simple
/// card UI the spec asks for (ui-feature-spec §39).
class DailySummary extends Equatable {
  const DailySummary({
    required this.date,
    required this.totalBookings,
    required this.confirmed,
    required this.waiting,
    required this.inService,
    required this.completed,
    required this.cancelled,
    required this.noShow,
    required this.queueActive,
    required this.averageWaitMinutes,
    required this.grossPaid,
    required this.pendingPayments,
    required this.refunded,
  });

  /// `YYYY-MM-DD` in the outlet timezone (Asia/Jakarta).
  final String date;
  final int totalBookings;
  final int confirmed;
  final int waiting;
  final int inService;
  final int completed;
  final int cancelled;
  final int noShow;
  final int queueActive;
  final int averageWaitMinutes;
  final Money grossPaid;
  final Money pendingPayments;
  final Money refunded;

  @override
  List<Object?> get props => [
    date,
    totalBookings,
    confirmed,
    waiting,
    inService,
    completed,
    cancelled,
    noShow,
    queueActive,
    averageWaitMinutes,
    grossPaid,
    pendingPayments,
    refunded,
  ];
}
