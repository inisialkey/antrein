import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'queue_models.freezed.dart';
part 'queue_models.g.dart';

/// Wire model for the customer queue resource (§80) and the check-in response
/// `queue` block (§64). The §64 block omits bookingId/version/timestamps, so
/// those are optional/defaulted; the datasource injects bookingId on check-in.
@freezed
abstract class QueueEntryModel with _$QueueEntryModel {
  const QueueEntryModel._();

  const factory QueueEntryModel({
    required String id,
    required String bookingId,
    required String businessDate,
    required int queueNumber,
    required String displayNumber,
    required String status,
    required int peopleAhead,
    required int estimatedWaitMinutes,
    String? currentServingNumber,
    DateTime? calledAt,
    DateTime? serviceStartedAt,
    DateTime? completedAt,
    @Default(0) int version,
  }) = _QueueEntryModel;

  factory QueueEntryModel.fromJson(Map<String, dynamic> json) =>
      _$QueueEntryModelFromJson(json);

  QueueEntry toEntity() => QueueEntry(
    id: id,
    bookingId: bookingId,
    businessDate: businessDate,
    queueNumber: queueNumber,
    displayNumber: displayNumber,
    status: QueueStatus.fromWire(status),
    peopleAhead: peopleAhead,
    estimatedWaitMinutes: estimatedWaitMinutes,
    currentServingNumber: currentServingNumber,
    calledAt: calledAt,
    serviceStartedAt: serviceStartedAt,
    completedAt: completedAt,
    version: version,
  );
}
