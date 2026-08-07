import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/profile/domain/entities/notification_preferences.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class ProfileRemoteDataSource {
  Future<void> updateProfile(ProfileDraft draft);

  Future<NotificationPreferences> getPreferences();

  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  );
}

@LazySingleton(as: ProfileRemoteDataSource)
class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<void> updateProfile(ProfileDraft draft) => sendEnvelope(
    () => _dio.patch<dynamic>(
      ApiEndpoints.me,
      data: {
        'name': draft.name,
        // Explicit null clears the number (§32); the form always sends it.
        'phoneNumber': draft.phoneNumber,
        if (draft.clearAvatar)
          'avatarFileId': null
        else if (draft.avatarFileId != null)
          'avatarFileId': draft.avatarFileId,
      },
    ),
  );

  /// ponytail: preferences ride along on `/me` rather than getting their own
  /// read — §33 only defines the write, and `/me` is one request either way.
  @override
  Future<NotificationPreferences> getPreferences() async {
    final data = await sendEnvelope(() => _dio.get<dynamic>(ApiEndpoints.me));
    final prefs = data['notificationPreferences'];
    return NotificationPreferences.fromJson(
      prefs is Map ? prefs.cast<String, dynamic>() : const {},
    );
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    final data = await sendEnvelope(
      () => _dio.patch<dynamic>(
        ApiEndpoints.meNotificationPreferences,
        data: preferences.toJson(),
      ),
    );
    return NotificationPreferences.fromJson(data);
  }
}
