part of 'business_detail_cubit.dart';

@freezed
sealed class BusinessDetailState with _$BusinessDetailState {
  const factory BusinessDetailState.initial() = BusinessDetailInitial;
  const factory BusinessDetailState.loading() = BusinessDetailLoading;
  const factory BusinessDetailState.loaded(BusinessProfile profile) =
      BusinessDetailLoaded;
  const factory BusinessDetailState.error(String message) = BusinessDetailError;
}
