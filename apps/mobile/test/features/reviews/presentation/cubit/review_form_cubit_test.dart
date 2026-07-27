import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/features/reviews/domain/usecases/create_review.dart';
import 'package:antrein/features/reviews/presentation/cubit/review_form_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateReview extends Mock implements CreateReview {}

void main() {
  late MockCreateReview createReview;

  setUpAll(() {
    registerFallbackValue(
      const CreateReviewParams(bookingId: '', rating: 1, idempotencyKey: ''),
    );
  });

  setUp(() => createReview = MockCreateReview());

  blocTest<ReviewFormCubit, ReviewFormState>(
    'emits submitting then success and sends rating + comment',
    build: () => ReviewFormCubit(createReview),
    setUp: () => when(
      () => createReview(any()),
    ).thenAnswer((_) async => const Right(null)),
    act: (cubit) => cubit.submit('bkg_1', rating: 4, comment: 'Rapi.'),
    expect: () => const [
      ReviewFormState.submitting(),
      ReviewFormState.success(),
    ],
    verify: (_) {
      final params =
          verify(
                () => createReview(captureAny()),
              ).captured.single
              as CreateReviewParams;
      expect(params.bookingId, 'bkg_1');
      expect(params.rating, 4);
      expect(params.comment, 'Rapi.');
      expect(params.idempotencyKey, isNotEmpty);
    },
  );

  blocTest<ReviewFormCubit, ReviewFormState>(
    'surfaces the backend error code (already reviewed)',
    build: () => ReviewFormCubit(createReview),
    setUp: () => when(() => createReview(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          'Already reviewed.',
          code: ApiErrorCodes.reviewAlreadyExists,
        ),
      ),
    ),
    act: (cubit) => cubit.submit('bkg_1', rating: 5),
    expect: () => const [
      ReviewFormState.submitting(),
      ReviewFormState.error(
        'Already reviewed.',
        code: ApiErrorCodes.reviewAlreadyExists,
      ),
    ],
  );

  blocTest<ReviewFormCubit, ReviewFormState>(
    'keeps the same key across an ambiguous transport-failure retry',
    build: () => ReviewFormCubit(createReview),
    setUp: () {
      final answers = <Either<Failure, void>>[
        const Left(NetworkFailure('Connection lost.')),
        const Right(null),
      ];
      when(
        () => createReview(any()),
      ).thenAnswer((_) async => answers.removeAt(0));
    },
    act: (cubit) async {
      await cubit.submit('bkg_1', rating: 3);
      await cubit.submit('bkg_1', rating: 3);
    },
    verify: (_) {
      final keys = verify(() => createReview(captureAny())).captured
          .cast<CreateReviewParams>()
          .map((p) => p.idempotencyKey)
          .toList();
      expect(keys, hasLength(2));
      expect(keys[0], keys[1]);
    },
  );

  blocTest<ReviewFormCubit, ReviewFormState>(
    'rotates the key after a coded (definitive) rejection',
    build: () => ReviewFormCubit(createReview),
    setUp: () {
      final answers = <Either<Failure, void>>[
        const Left(
          ServerFailure(
            'Not completed.',
            code: ApiErrorCodes.reviewBookingNotCompleted,
          ),
        ),
        const Right(null),
      ];
      when(
        () => createReview(any()),
      ).thenAnswer((_) async => answers.removeAt(0));
    },
    act: (cubit) async {
      await cubit.submit('bkg_1', rating: 3);
      await cubit.submit('bkg_1', rating: 3);
    },
    verify: (_) {
      final keys = verify(() => createReview(captureAny())).captured
          .cast<CreateReviewParams>()
          .map((p) => p.idempotencyKey)
          .toList();
      expect(keys[0], isNot(keys[1]));
    },
  );
}
