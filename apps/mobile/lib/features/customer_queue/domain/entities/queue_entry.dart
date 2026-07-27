import 'package:antrein/features/customer_queue/domain/entities/queue_status.dart';
import 'package:equatable/equatable.dart';

/// The customer's own queue position (api-contract §80). Never exposes any other
/// customer — only aggregate figures (people ahead, current serving number).
class QueueEntry extends Equatable {
  const QueueEntry({
    required this.id,
    required this.bookingId,
    required this.businessDate,
    required this.queueNumber,
    required this.displayNumber,
    required this.status,
    required this.peopleAhead,
    required this.estimatedWaitMinutes,
    this.currentServingNumber,
    this.calledAt,
    this.serviceStartedAt,
    this.completedAt,
    this.version = 0,
  });

  final String id;
  final String bookingId;

  /// Operational day in the outlet timezone (`YYYY-MM-DD`).
  final String businessDate;
  final int queueNumber;

  /// Human label, e.g. `A012`.
  final String displayNumber;
  final QueueStatus status;
  final int peopleAhead;
  final int estimatedWaitMinutes;

  /// Display number currently being served/called at the outlet, if any.
  final String? currentServingNumber;
  final DateTime? calledAt;
  final DateTime? serviceStartedAt;
  final DateTime? completedAt;
  final int version;

  bool get isTerminal => status.isTerminal;
  bool get isCalled => status.isCalled;

  @override
  List<Object?> get props => [
    id,
    bookingId,
    businessDate,
    queueNumber,
    displayNumber,
    status,
    peopleAhead,
    estimatedWaitMinutes,
    currentServingNumber,
    calledAt,
    serviceStartedAt,
    completedAt,
    version,
  ];
}
