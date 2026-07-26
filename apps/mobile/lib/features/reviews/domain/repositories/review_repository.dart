import 'package:antrein/core/utils/typedefs.dart';

abstract class ReviewRepository {
  /// Creates the review for a completed booking (contract §96). The backend
  /// answers with the review row; the form only needs success/failure, so the
  /// result carries no payload.
  ResultFuture<void> createReview({
    required String bookingId,
    required int rating,
    required String idempotencyKey,
    String? comment,
  });
}
