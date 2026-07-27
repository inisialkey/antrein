import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/customer_queue/data/models/queue_models.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class QueueRemoteDataSource {
  Future<QueueEntryModel> checkIn({
    required String bookingId,
    required String idempotencyKey,
    String method,
  });

  Future<QueueEntryModel> getQueue(String bookingId);
}

@LazySingleton(as: QueueRemoteDataSource)
class QueueRemoteDataSourceImpl implements QueueRemoteDataSource {
  const QueueRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<QueueEntryModel> checkIn({
    required String bookingId,
    required String idempotencyKey,
    String method = 'customer_app',
  }) async {
    final data = await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.checkIn(bookingId),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {'method': method},
      ),
    );
    // §64 response: { bookingId, bookingStatus, checkedInAt, queue: {...} }.
    // The queue block omits bookingId — inject it from the request.
    final queue = (data['queue'] as Map).cast<String, dynamic>();
    queue['bookingId'] = bookingId;
    return QueueEntryModel.fromJson(queue);
  }

  @override
  Future<QueueEntryModel> getQueue(String bookingId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(ApiEndpoints.customerQueue(bookingId)),
    );
    return QueueEntryModel.fromJson((data as Map).cast<String, dynamic>());
  }
}
