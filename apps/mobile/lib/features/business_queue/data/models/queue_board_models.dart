import 'package:antrein/features/business_queue/domain/entities/queue_board.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_board_entry.dart';
import 'package:antrein/features/customer_queue/customer_queue.dart'
    show QueueStatus;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'queue_board_models.freezed.dart';
part 'queue_board_models.g.dart';

/// Wire model for the outlet queue snapshot (§82). `currentServing` is null when
/// nobody is called/in-service; `waiting`/`skipped` default to empty lists.
@freezed
abstract class QueueBoardModel with _$QueueBoardModel {
  const QueueBoardModel._();

  const factory QueueBoardModel({
    required String businessDate,
    required String outletId,
    @Default(true) bool isOpen,
    @Default(1) int version,
    QueueBoardEntryModel? currentServing,
    @Default(<QueueBoardEntryModel>[]) List<QueueBoardEntryModel> waiting,
    @Default(<QueueBoardEntryModel>[]) List<QueueBoardEntryModel> skipped,
    DateTime? updatedAt,
  }) = _QueueBoardModel;

  factory QueueBoardModel.fromJson(Map<String, dynamic> json) =>
      _$QueueBoardModelFromJson(json);

  QueueBoard toEntity() => QueueBoard(
    businessDate: businessDate,
    outletId: outletId,
    isOpen: isOpen,
    version: version,
    currentServing: currentServing?.toEntity(),
    waiting: waiting.map((e) => e.toEntity()).toList(growable: false),
    skipped: skipped.map((e) => e.toEntity()).toList(growable: false),
    updatedAt: updatedAt,
  );
}

/// One snapshot item (§82). `customer`/`service`/`staff` are nested objects that
/// may be null or carry null names; the staff snapshot never includes a phone.
@freezed
abstract class QueueBoardEntryModel with _$QueueBoardEntryModel {
  const QueueBoardEntryModel._();

  const factory QueueBoardEntryModel({
    required String queueEntryId,
    required String displayNumber,
    required String bookingId,
    required String status,
    @Default(1) int version,
    QueueNamedRefModel? customer,
    QueueNamedRefModel? service,
    QueueStaffRefModel? staff,
    DateTime? checkedInAt,
  }) = _QueueBoardEntryModel;

  factory QueueBoardEntryModel.fromJson(Map<String, dynamic> json) =>
      _$QueueBoardEntryModelFromJson(json);

  QueueBoardEntry toEntity() => QueueBoardEntry(
    queueEntryId: queueEntryId,
    displayNumber: displayNumber,
    bookingId: bookingId,
    status: QueueStatus.fromWire(status),
    version: version,
    customerName: customer?.name,
    serviceName: service?.name,
    staffId: staff?.id,
    staffName: staff?.name,
    checkedInAt: checkedInAt,
  );
}

@freezed
abstract class QueueNamedRefModel with _$QueueNamedRefModel {
  const factory QueueNamedRefModel({String? name}) = _QueueNamedRefModel;

  factory QueueNamedRefModel.fromJson(Map<String, dynamic> json) =>
      _$QueueNamedRefModelFromJson(json);
}

@freezed
abstract class QueueStaffRefModel with _$QueueStaffRefModel {
  const factory QueueStaffRefModel({String? id, String? name}) =
      _QueueStaffRefModel;

  factory QueueStaffRefModel.fromJson(Map<String, dynamic> json) =>
      _$QueueStaffRefModelFromJson(json);
}
