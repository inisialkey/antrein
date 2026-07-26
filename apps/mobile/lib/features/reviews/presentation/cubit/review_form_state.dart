part of 'review_form_cubit.dart';

@freezed
sealed class ReviewFormState with _$ReviewFormState {
  const factory ReviewFormState.initial() = ReviewFormInitial;
  const factory ReviewFormState.submitting() = ReviewFormSubmitting;
  const factory ReviewFormState.success() = ReviewFormSuccess;
  const factory ReviewFormState.error(String message, {String? code}) =
      ReviewFormError;
}
