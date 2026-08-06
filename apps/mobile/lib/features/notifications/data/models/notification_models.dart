import 'package:antrein/features/notifications/domain/entities/app_notification.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_models.freezed.dart';
part 'notification_models.g.dart';

/// Wire model for the notification resource (api-contract §92).
@freezed
abstract class NotificationModel with _$NotificationModel {
  const NotificationModel._();

  const factory NotificationModel({
    required String id,
    required String type,
    required String title,
    required String body,
    required bool isRead,
    required DateTime createdAt,
    NotificationResourceModel? resource,
    DateTime? readAt,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  AppNotification toEntity() => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    isRead: isRead,
    createdAt: createdAt,
    resourceType: resource?.type,
    resourceId: resource?.id,
    readAt: readAt,
  );
}

@freezed
abstract class NotificationResourceModel with _$NotificationResourceModel {
  const factory NotificationResourceModel({
    required String type,
    required String id,
  }) = _NotificationResourceModel;

  factory NotificationResourceModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationResourceModelFromJson(json);
}
