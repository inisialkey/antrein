import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/reviews/data/datasources/review_remote_data_source.dart';
import 'package:antrein/features/reviews/domain/repositories/review_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ReviewRepository)
class ReviewRepositoryImpl implements ReviewRepository {
  const ReviewRepositoryImpl(this._remote);

  final ReviewRemoteDataSource _remote;

  @override
  ResultFuture<void> createReview({
    required String bookingId,
    required int rating,
    required String idempotencyKey,
    String? comment,
  }) async {
    try {
      await _remote.createReview(
        bookingId: bookingId,
        rating: rating,
        comment: comment,
        idempotencyKey: idempotencyKey,
      );
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'createReview'));
    }
  }
}
