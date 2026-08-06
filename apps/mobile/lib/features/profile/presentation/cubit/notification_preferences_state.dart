part of 'notification_preferences_cubit.dart';

enum PreferencesStatus { initial, loading, success, failure }

@freezed
abstract class NotificationPreferencesState
    with _$NotificationPreferencesState {
  const factory NotificationPreferencesState({
    @Default(PreferencesStatus.initial) PreferencesStatus status,
    @Default(NotificationPreferences()) NotificationPreferences preferences,
    @Default(false) bool isSaving,
    String? message,

    /// Bumped on every accepted write so the page can confirm without the
    /// cubit knowing a single localized string.
    @Default(0) int savedTick,
  }) = _NotificationPreferencesState;
}
