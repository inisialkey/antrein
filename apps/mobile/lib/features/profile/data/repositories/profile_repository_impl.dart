import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:antrein/features/profile/domain/entities/notification_preferences.dart';
import 'package:antrein/features/profile/domain/repositories/profile_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  ResultVoid updateProfile(ProfileDraft draft) async {
    try {
      await _remote.updateProfile(draft);
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'updateProfile'));
    }
  }

  @override
  ResultFuture<NotificationPreferences> getPreferences() async {
    try {
      return Right(await _remote.getPreferences());
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'getPreferences'));
    }
  }

  @override
  ResultFuture<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    try {
      return Right(await _remote.updatePreferences(preferences));
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'updatePreferences'));
    }
  }
}
