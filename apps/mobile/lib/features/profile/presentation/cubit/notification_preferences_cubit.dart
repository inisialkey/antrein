import 'package:antrein/core/error/failures.dart';
import 'package:antrein/features/profile/domain/entities/notification_preferences.dart';
import 'package:antrein/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'notification_preferences_state.dart';
part 'notification_preferences_cubit.freezed.dart';

/// Notification switches (api-contract §33). Each toggle writes immediately —
/// there is nothing to validate and no other field to keep in step, so a Save
/// button would only add a way to lose the change.
@injectable
class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState> {
  NotificationPreferencesCubit(this._repo)
    : super(const NotificationPreferencesState());

  final ProfileRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(status: PreferencesStatus.loading, message: null));
    final result = await _repo.getPreferences();
    if (isClosed) return;
    result.match(
      (failure) => emit(
        state.copyWith(
          status: PreferencesStatus.failure,
          message: failure.message,
        ),
      ),
      (preferences) => emit(
        state.copyWith(
          status: PreferencesStatus.success,
          preferences: preferences,
        ),
      ),
    );
  }

  Future<void> toggle(NotificationPreferences next) async {
    if (state.isSaving) return;
    final previous = state.preferences;
    // Optimistic: the switch follows the finger, and a rejection puts it back.
    emit(state.copyWith(isSaving: true, preferences: next, message: null));

    final result = await _repo.updatePreferences(next);
    if (isClosed) return;
    final failure = result.match<Failure?>((f) => f, (_) => null);
    emit(
      state.copyWith(
        isSaving: false,
        preferences: failure == null
            ? result.match((_) => next, (saved) => saved)
            : previous,
        message: failure?.message,
        savedTick: failure == null ? state.savedTick + 1 : state.savedTick,
      ),
    );
  }
}
