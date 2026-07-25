import 'package:antrein/features/customer_queue/customer_queue.dart'
    show QueueStatus;
import 'package:equatable/equatable.dart';

/// One row on the staff queue board (contract §82 snapshot item). Operational
/// fields only — never a phone number (ADR 0041). [version] is the entry's own
/// optimistic-concurrency version, supplied as `expectedVersion` on commands.
class QueueBoardEntry extends Equatable {
  const QueueBoardEntry({
    required this.queueEntryId,
    required this.displayNumber,
    required this.bookingId,
    required this.status,
    required this.version,
    this.customerName,
    this.serviceName,
    this.staffId,
    this.staffName,
    this.checkedInAt,
  });

  final String queueEntryId;
  final String displayNumber;
  final String bookingId;
  final QueueStatus status;
  final int version;
  final String? customerName;
  final String? serviceName;
  final String? staffId;
  final String? staffName;
  final DateTime? checkedInAt;

  @override
  List<Object?> get props => [
    queueEntryId,
    displayNumber,
    bookingId,
    status,
    version,
    customerName,
    serviceName,
    staffId,
    staffName,
    checkedInAt,
  ];
}
