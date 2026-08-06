part of 'business_settings_cubit.dart';

enum SettingsStatus { initial, loading, success, failure }

@freezed
abstract class BusinessSettingsState with _$BusinessSettingsState {
  const factory BusinessSettingsState({
    @Default(SettingsStatus.initial) SettingsStatus status,

    /// Last known server values — the form seeds itself from these.
    ManagedBusiness? business,
    ManagedOutlet? outlet,
    @Default(false) bool isSaving,

    /// Bumped on every successful save so the page can show a localized
    /// confirmation without the cubit knowing about l10n.
    @Default(0) int savedTick,
    String? message,
  }) = _BusinessSettingsState;
}
