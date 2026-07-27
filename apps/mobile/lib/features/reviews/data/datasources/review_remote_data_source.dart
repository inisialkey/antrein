import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class ReviewRemoteDataSource {
  Future<void> createReview({
    required String bookingId,
    required int rating,
    required String idempotencyKey,
    String? comment,
  });
}

@LazySingleton(as: ReviewRemoteDataSource)
class ReviewRemoteDataSourceImpl implements ReviewRemoteDataSource {
  const ReviewRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> createReview({
    required String bookingId,
    required int rating,
    required String idempotencyKey,
    String? comment,
  }) async {
    // §96 answers with the review row; the form has no use for it.
    await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.bookingReview(bookingId),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {'rating': rating, 'comment': ?comment},
      ),
    );
  }
}
