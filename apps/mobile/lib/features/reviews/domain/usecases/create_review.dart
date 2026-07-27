import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/reviews/domain/repositories/review_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class CreateReview extends UseCase<void, CreateReviewParams> {
  const CreateReview(this._repository);

  final ReviewRepository _repository;

  @override
  ResultFuture<void> call(CreateReviewParams params) =>
      _repository.createReview(
        bookingId: params.bookingId,
        rating: params.rating,
        comment: params.comment,
        idempotencyKey: params.idempotencyKey,
      );
}

class CreateReviewParams extends Equatable {
  const CreateReviewParams({
    required this.bookingId,
    required this.rating,
    required this.idempotencyKey,
    this.comment,
  });

  final String bookingId;
  final int rating;
  final String idempotencyKey;
  final String? comment;

  @override
  List<Object?> get props => [bookingId, rating, idempotencyKey, comment];
}
