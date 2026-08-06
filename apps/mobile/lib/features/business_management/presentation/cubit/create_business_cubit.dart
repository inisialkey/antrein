import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/utils/idempotency.dart';
import 'package:antrein/features/business_management/domain/repositories/business_management_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Self-serve business registration (api-contract §43, ADR 0013 — businesses
/// go active immediately). The state is just "is a submission in flight"; the
/// outcome is returned so the page can refresh `/me` and move on.
@injectable
class CreateBusinessCubit extends Cubit<bool> {
  CreateBusinessCubit(this._repo) : super(false);

  final BusinessManagementRepository _repo;
  String? _key;

  /// Returns null on success, otherwise the message to show.
  Future<String?> submit({
    required String name,
    required String outletName,
    required String address,
    String? description,
    String? phoneNumber,
  }) async {
    if (state) return null;
    emit(true);

    final result = await _repo.createBusiness(
      name: name,
      outletName: outletName,
      address: address,
      description: description,
      phoneNumber: phoneNumber,
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
