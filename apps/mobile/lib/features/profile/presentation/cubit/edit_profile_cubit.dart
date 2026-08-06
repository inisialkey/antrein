import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/files/file_upload_repository.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/profile/domain/entities/notification_preferences.dart';
import 'package:antrein/features/profile/domain/repositories/profile_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// The account's own profile write (api-contract §32). The state is just
/// "is a submission in flight" — the page keeps the form, and the caller
/// re-reads `/me` so the shell sees the new name and avatar.
@injectable
class EditProfileCubit extends Cubit<bool> {
  EditProfileCubit(this._repo, this._files) : super(false);

  final ProfileRepository _repo;
  final FileUploadRepository _files;

  /// Uploads an avatar (§36); the form holds the id until save attaches it.
  ResultFuture<UploadedImage> uploadAvatar(String path) =>
      _files.upload(filePath: path, purpose: FilePurpose.customerAvatar);

  /// Returns null on success, otherwise the message to show. §32 is not an
  /// idempotent-key endpoint — a repeated PATCH lands the same values.
  Future<String?> save(ProfileDraft draft) async {
    if (state) return null;
    emit(true);

    final result = await _repo.updateProfile(draft);
    if (isClosed) return null;
    emit(false);
    return result.match<Failure?>((f) => f, (_) => null)?.message;
  }
}
