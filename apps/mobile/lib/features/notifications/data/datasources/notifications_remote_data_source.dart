import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/notifications/data/models/notification_models.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

typedef NotificationPageDto = ({
  List<NotificationModel> items,
  String? nextCursor,
});

abstract class NotificationsRemoteDataSource {
  Future<NotificationPageDto> list({bool? isRead, String? cursor, int? limit});

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();
}

@LazySingleton(as: NotificationsRemoteDataSource)
class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  const NotificationsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<NotificationPageDto> list({
    bool? isRead,
    String? cursor,
    int? limit,
  }) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.notifications,
        queryParameters: {
          // The backend takes the flag as the string 'true'/'false' (§92).
          if (isRead != null) 'isRead': '$isRead',
          'cursor': ?cursor,
          'limit': ?limit,
        },
      ),
    );
    final pagination = data['pagination'];
    return (
      items: ((data['items'] as List<dynamic>?) ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => NotificationModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      nextCursor: pagination is Map
          ? pagination['nextCursor'] as String?
          : null,
    );
  }

  @override
  Future<void> markRead(String notificationId) async {
    await sendEnvelope(
      () => _dio.post<dynamic>(ApiEndpoints.notificationRead(notificationId)),
    );
  }

  @override
  Future<void> markAllRead() async {
    await sendEnvelope(
      () => _dio.post<dynamic>(ApiEndpoints.notificationsReadAll),
    );
  }
}
