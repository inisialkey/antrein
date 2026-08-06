part of 'service_management_cubit.dart';

enum ServiceListStatus { initial, loading, success, empty, failure }

@freezed
abstract class ServiceManagementState with _$ServiceManagementState {
  const factory ServiceManagementState({
    @Default(ServiceListStatus.initial) ServiceListStatus status,
    @Default(<ManagedService>[]) List<ManagedService> services,
    @Default(<StaffOption>[]) List<StaffOption> staff,
    @Default(false) bool isRefreshing,
    @Default(false) bool isSaving,

    /// The service a deactivate is running for — locks the row's actions.
    String? actingServiceId,
    String? message,
  }) = _ServiceManagementState;
}
