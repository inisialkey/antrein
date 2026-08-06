import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/utils/idempotency.dart';
import 'package:antrein/features/staff_management/domain/repositories/staff_management_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Accepts a staff invitation with the signed-in account (api-contract §51).
/// The state is just "is a submission in flight" — the outcome is returned to
/// the caller so the dialog can close itself or show the rejection.
@injectable
class AcceptInvitationCubit extends Cubit<bool> {
  AcceptInvitationCubit(this._repo) : super(false);

  final StaffManagementRepository _repo;
  String? _key;

  /// Returns null on success, otherwise the message to show.
  Future<String?> accept(String invitationId) async {
    if (state) return null;
    emit(true);

    final result = await _repo.acceptInvitation(
      invitationId.trim(),
      idempotencyKey: _key ??= newIdempotencyKey(),
    );
    if (isClosed) return null;
    emit(false);

    final failure = result.match<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      // A coded rejection is stored against the key; replaying it replays the
      // rejection, so the next attempt needs a fresh one.
      if (failure.code != null) _key = null;
      return failure.message;
    }
    _key = null;
    return null;
  }
}
