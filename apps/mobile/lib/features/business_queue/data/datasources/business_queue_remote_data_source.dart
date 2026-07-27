import 'package:antrein/core/error/exceptions.dart';
import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/business_queue/data/models/queue_board_models.dart';
import 'package:antrein/features/business_queue/domain/entities/queue_command.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class BusinessQueueRemoteDataSource {
  Future<QueueBoardModel> getBoard(
    String businessId,
    String outletId, {
    String? date,
  });

  Future<void> runCommand({
    required String businessId,
    required String queueEntryId,
    required QueueCommand command,
    required int expectedVersion,
    required String idempotencyKey,
    String? reason,
    String? staffId,
  });

  /// `POST /businesses/{id}/walk-ins` (§67); returns the queue display number.
  Future<String> createWalkIn({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String customerName,
    required String idempotencyKey,
    String? phoneNumber,
  });

  /// `POST .../queue/reorder` (§90).
  Future<void> reorderQueue({
    required String businessId,
    required String outletId,
    required String businessDate,
    required int expectedQueueVersion,
    required List<String> orderedQueueEntryIds,
    required String reason,
    required String idempotencyKey,
  });

  Future<String> primaryOutletId(String businessId);
}

@LazySingleton(as: BusinessQueueRemoteDataSource)
class BusinessQueueRemoteDataSourceImpl
    implements BusinessQueueRemoteDataSource {
  const BusinessQueueRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<QueueBoardModel> getBoard(
    String businessId,
    String outletId, {
    String? date,
  }) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.outletQueue(businessId, outletId),
        queryParameters: {'date': ?date},
      ),
    );
    return QueueBoardModel.fromJson(data);
  }

  @override
  Future<void> runCommand({
    required String businessId,
    required String queueEntryId,
    required QueueCommand command,
    required int expectedVersion,
    required String idempotencyKey,
    String? reason,
    String? staffId,
  }) async {
    await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.queueCommand(businessId, queueEntryId, command.path),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {
          'expectedVersion': expectedVersion,
          ..._commandBody(command, reason: reason, staffId: staffId),
        },
      ),
    );
  }

  @override
  Future<String> createWalkIn({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String customerName,
    required String idempotencyKey,
    String? phoneNumber,
  }) async {
    final data = await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.walkIns(businessId),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {
          'outletId': outletId,
          'customer': {'name': customerName, 'phoneNumber': ?phoneNumber},
          'serviceId': serviceId,
          // ponytail: walk-ins always join as any-available — a specific barber
          // is assigned at start-service (§87 staffId override). Add a staff
          // picker here only if assignment-at-entry becomes a real need.
          'staffSelection': {'mode': 'any_available'},
          'paymentOption': 'pay_at_location',
        },
      ),
    );
    final queue = (data['queue'] as Map?)?.cast<String, dynamic>();
    return queue?['displayNumber'] as String? ?? '';
  }

  @override
  Future<void> reorderQueue({
    required String businessId,
    required String outletId,
    required String businessDate,
    required int expectedQueueVersion,
    required List<String> orderedQueueEntryIds,
    required String reason,
    required String idempotencyKey,
  }) async {
    await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.queueReorder(businessId, outletId),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {
          'businessDate': businessDate,
          'expectedQueueVersion': expectedQueueVersion,
          'orderedQueueEntryIds': orderedQueueEntryIds,
          'reason': reason,
        },
      ),
    );
  }

  @override
  Future<String> primaryOutletId(String businessId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(ApiEndpoints.businessDetail(businessId)),
    );
    // The public business profile (§39) lists outlets; MVP has one active outlet
    // per business (ADR 0038), so the first is the queue to manage.
    final outlets = (data['outlets'] as List<dynamic>?) ?? const [];
    if (outlets.isEmpty) {
      throw const ServerException('This business has no outlet yet.');
    }
    return (outlets.first as Map).cast<String, dynamic>()['id'] as String;
  }

  /// Per-command request body: skip/no-show carry an optional reason, complete an
  /// internal note, start-service an optional staff override. call/recall/return
  /// send only `expectedVersion`.
  Map<String, dynamic> _commandBody(
    QueueCommand command, {
    String? reason,
    String? staffId,
  }) => switch (command) {
    QueueCommand.skip || QueueCommand.noShow => {'reason': ?reason},
    QueueCommand.complete => {'internalNote': ?reason},
    QueueCommand.startService => {'staffId': ?staffId},
    _ => const {},
  };
}
