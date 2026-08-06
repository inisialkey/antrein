import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/notifications/domain/entities/app_notification.dart';

abstract class NotificationsRepository {
  /// One keyset page of the signed-in user's notifications (§92). [isRead] null
  /// means both; pass false for the unread filter and the badge count.
  ResultFuture<NotificationPage> list({
    bool? isRead,
    String? cursor,
    int? limit,
  });

  ResultVoid markRead(String notificationId);

  ResultVoid markAllRead();
}
