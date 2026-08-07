import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/profile/domain/entities/notification_preferences.dart';

/// The account's own `/me` writes (api-contract §32, §33).
abstract class ProfileRepository {
  ResultVoid updateProfile(ProfileDraft draft);

  ResultFuture<NotificationPreferences> getPreferences();

  ResultFuture<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  );
}
