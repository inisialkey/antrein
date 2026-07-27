part of 'discovery_cubit.dart';

@freezed
sealed class DiscoveryState with _$DiscoveryState {
  const factory DiscoveryState.initial() = DiscoveryInitial;
  const factory DiscoveryState.loading() = DiscoveryLoading;
  const factory DiscoveryState.loaded(List<BusinessSummary> businesses) =
      DiscoveryLoaded;
  const factory DiscoveryState.empty() = DiscoveryEmpty;
  const factory DiscoveryState.error(String message) = DiscoveryError;
}
