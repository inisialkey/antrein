import 'package:equatable/equatable.dart';

/// The four switches behind `PATCH /me/notification-preferences` (§33).
/// `queueUpdates` is the one the backend actually gates push on today — the
/// others are stored and reserved for the categories that follow.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.bookingUpdates = true,
    this.paymentUpdates = true,
    this.queueUpdates = true,
    this.marketing = false,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        bookingUpdates: json['bookingUpdates'] as bool? ?? true,
        paymentUpdates: json['paymentUpdates'] as bool? ?? true,
        queueUpdates: json['queueUpdates'] as bool? ?? true,
        marketing: json['marketing'] as bool? ?? false,
      );

  final bool bookingUpdates;
  final bool paymentUpdates;
  final bool queueUpdates;
  final bool marketing;

  NotificationPreferences copyWith({
    bool? bookingUpdates,
    bool? paymentUpdates,
    bool? queueUpdates,
    bool? marketing,
  }) => NotificationPreferences(
    bookingUpdates: bookingUpdates ?? this.bookingUpdates,
    paymentUpdates: paymentUpdates ?? this.paymentUpdates,
    queueUpdates: queueUpdates ?? this.queueUpdates,
    marketing: marketing ?? this.marketing,
  );

  Map<String, dynamic> toJson() => {
    'bookingUpdates': bookingUpdates,
    'paymentUpdates': paymentUpdates,
    'queueUpdates': queueUpdates,
    'marketing': marketing,
  };

  @override
  List<Object?> get props => [
    bookingUpdates,
    paymentUpdates,
    queueUpdates,
    marketing,
  ];
}

/// What the edit-profile form submits (§32). The form always carries both text
/// fields, so an empty [phoneNumber] means "clear it", not "leave it".
/// [avatarFileId] attaches a fresh upload; [clearAvatar] removes the current
/// one — sending neither leaves the avatar alone.
class ProfileDraft extends Equatable {
  const ProfileDraft({
    required this.name,
    this.phoneNumber,
    this.avatarFileId,
    this.clearAvatar = false,
  });

  final String name;
  final String? phoneNumber;
  final String? avatarFileId;
  final bool clearAvatar;

  @override
  List<Object?> get props => [name, phoneNumber, avatarFileId, clearAvatar];
}
