import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:antrein/features/notifications/domain/entities/app_notification.dart';
import 'package:antrein/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: NotificationsRepository)
class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl(this._remote);

  final NotificationsRemoteDataSource _remote;

  @override
  ResultFuture<NotificationPage> list({
    bool? isRead,
    String? cursor,
    int? limit,
  }) => _guard('list', () async {
    final page = await _remote.list(
      isRead: isRead,
      cursor: cursor,
      limit: limit,
    );
    return NotificationPage(
      items: page.items.map((m) => m.toEntity()).toList(),
      nextCursor: page.nextCursor,
    );
  });

  @override
  ResultVoid markRead(String notificationId) =>
      _guard('markRead', () => _remote.markRead(notificationId));

  @override
  ResultVoid markAllRead() => _guard('markAllRead', _remote.markAllRead);

  Future<Either<Failure, T>> _guard<T>(
    String label,
    Future<T> Function() action,
  ) async {
    try {
      return Right(await action());
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, label));
    }
  }
}
