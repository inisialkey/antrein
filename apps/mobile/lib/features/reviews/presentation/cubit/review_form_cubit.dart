import 'dart:math';

import 'package:antrein/features/reviews/domain/usecases/create_review.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'review_form_state.dart';
part 'review_form_cubit.freezed.dart';

/// Drives the review form on a completed booking (contract §96).
@injectable
class ReviewFormCubit extends Cubit<ReviewFormState> {
  ReviewFormCubit(this._createReview) : super(const ReviewFormState.initial());

  final CreateReview _createReview;

  /// Kept across retries of one logical submission (CLAUDE.md idempotency
  /// rule); rotated after a coded rejection — the backend stores those as
  /// failed_final, so replaying the key replays the same error.
  String? _idempotencyKey;

  Future<void> submit(
    String bookingId, {
    required int rating,
    String? comment,
  }) async {
    if (state is ReviewFormSubmitting) return;
    emit(const ReviewFormState.submitting());
    final key = _idempotencyKey ??= _newKey();
    final trimmed = comment?.trim();
    final result = await _createReview(
      CreateReviewParams(
        bookingId: bookingId,
        rating: rating,
        comment: (trimmed?.isEmpty ?? true) ? null : trimmed,
        idempotencyKey: key,
      ),
    );
    result.match(
      (failure) {
        if (failure.code != null) _idempotencyKey = null;
        emit(ReviewFormState.error(failure.message, code: failure.code));
      },
      (_) {
        _idempotencyKey = null;
        emit(const ReviewFormState.success());
      },
    );
  }

  static String _newKey() {
    final random = Random();
    return 'idem_${DateTime.now().microsecondsSinceEpoch}_'
        '${random.nextInt(1 << 32).toRadixString(16)}';
  }
}
