import 'package:equatable/equatable.dart';

/// One in-app notification (api-contract §92). `Notification` is taken by both
/// Flutter and OneSignal, hence the prefix.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.resourceType,
    this.resourceId,
    this.readAt,
  });

  final String id;

  /// Backend notification type, e.g. `queue_called`. Free-form on the wire —
  /// kept as a string so a newer backend type never breaks an older app.
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  /// What the notification points at, e.g. `booking` + `bkg_…`. Both null when
  /// the notification is informational only.
  final String? resourceType;
  final String? resourceId;
  final DateTime? readAt;

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    body,
    isRead,
    createdAt,
    resourceType,
    resourceId,
    readAt,
  ];
}

/// One keyset page (§20). `nextCursor` is opaque and null on the last page.
class NotificationPage extends Equatable {
  const NotificationPage({required this.items, this.nextCursor});

  final List<AppNotification> items;
  final String? nextCursor;

  @override
  List<Object?> get props => [items, nextCursor];
}
