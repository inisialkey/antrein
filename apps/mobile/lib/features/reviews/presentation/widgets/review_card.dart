import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/reviews/presentation/cubit/review_form_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Inline review form shown on a completed booking (ui-feature-spec §28).
/// Self-contained [ReviewFormCubit], mirroring the check-in card.
class ReviewCard extends StatelessWidget {
  const ReviewCard({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<ReviewFormCubit>(),
    child: _ReviewCardView(bookingId: bookingId),
  );
}

class _ReviewCardView extends StatefulWidget {
  const _ReviewCardView({required this.bookingId});

  final String bookingId;

  @override
  State<_ReviewCardView> createState() => _ReviewCardViewState();
}

class _ReviewCardViewState extends State<_ReviewCardView> {
  int _rating = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<ReviewFormCubit, ReviewFormState>(
      listener: (context, state) {
        // Already-reviewed renders inline (builder); other errors toast.
        if (state case ReviewFormError(
          :final message,
          :final code,
        ) when code != ApiErrorCodes.reviewAlreadyExists) {
          context.showSnackBar(message.isEmpty ? l10n.reviewFailed : message);
        }
      },
      builder: (context, state) {
        // ponytail: the booking payload carries no "already reviewed" flag, so
        // the form always shows on completed bookings and collapses on the 409.
        final alreadyReviewed =
            state is ReviewFormError &&
            state.code == ApiErrorCodes.reviewAlreadyExists;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(Dimens.space16.r),
            child: switch (state) {
              ReviewFormSuccess() => _Notice(
                icon: Icons.check_circle_outline,
                text: l10n.reviewThanks,
              ),
              _ when alreadyReviewed => _Notice(
                icon: Icons.rate_review_outlined,
                text: l10n.reviewAlreadyExists,
              ),
              _ => _form(context, submitting: state is ReviewFormSubmitting),
            },
          ),
        );
      },
    );
  }

  Widget _form(BuildContext context, {required bool submitting}) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.reviewCardTitle, style: context.textTheme.titleSmall),
        const Gap(Dimens.space8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                onPressed: () => setState(() => _rating = star),
                icon: Icon(
                  star <= _rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: Dimens.iconLg.r,
                  color: star <= _rating
                      ? context.appColors.warning
                      : context.colorScheme.outline,
                ),
              ),
          ],
        ),
        const Gap(Dimens.space8),
        TextField(
          controller: _comment,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(hintText: l10n.reviewCommentHint),
        ),
        const Gap(Dimens.space12),
        AppButton(
          label: l10n.reviewSubmit,
          loading: submitting,
          onPressed: _rating == 0
              ? null
              : () => context.read<ReviewFormCubit>().submit(
                  widget.bookingId,
                  rating: _rating,
                  comment: _comment.text,
                ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: context.appColors.success, size: Dimens.iconMd.r),
      const Gap.horizontal(Dimens.space8),
      Expanded(child: Text(text, style: context.textTheme.bodyMedium)),
    ],
  );
}
