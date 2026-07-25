import 'package:antrein/features/business_queue/domain/entities/queue_board_entry.dart';
import 'package:equatable/equatable.dart';

/// The staff queue board for one outlet on one business date (contract §82).
///
/// The snapshot exposes a single [currentServing] slot — the in-service entry,
/// or the called entry when none is in service — plus the [waiting] and
/// [skipped] lists. Terminal entries are never included.
class QueueBoard extends Equatable {
  const QueueBoard({
    required this.businessDate,
    required this.outletId,
    required this.isOpen,
    required this.version,
    required this.waiting,
    required this.skipped,
    this.currentServing,
    this.updatedAt,
  });

  final String businessDate;
  final String outletId;
  final bool isOpen;

  /// Aggregate queue version (`queue_counters.version`) — bumped on reorder.
  final int version;
  final List<QueueBoardEntry> waiting;
  final List<QueueBoardEntry> skipped;
  final QueueBoardEntry? currentServing;
  final DateTime? updatedAt;

  int get activeCount =>
      waiting.length + skipped.length + (currentServing == null ? 0 : 1);

  bool get isEmpty => activeCount == 0;

  @override
  List<Object?> get props => [
    businessDate,
    outletId,
    isOpen,
    version,
    waiting,
    skipped,
    currentServing,
    updatedAt,
  ];
}
