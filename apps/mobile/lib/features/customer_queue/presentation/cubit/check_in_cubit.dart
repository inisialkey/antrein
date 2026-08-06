import 'package:antrein/core/utils/idempotency.dart';
import 'package:antrein/features/customer_queue/domain/entities/queue_entry.dart';
import 'package:antrein/features/customer_queue/domain/usecases/check_in.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'check_in_state.dart';
part 'check_in_cubit.freezed.dart';

/// Drives the check-in action on the booking detail screen (contract §64).
@injectable
class CheckInCubit extends Cubit<CheckInState> {
  CheckInCubit(this._checkIn) : super(const CheckInState.initial());

  final CheckIn _checkIn;

  /// Kept across retries of one logical submission (CLAUDE.md idempotency rule):
  /// if a check-in commits but its response is lost, retrying with the SAME key
  /// replays the stored success instead of colliding on UNIQUE(booking_id).
  String? _idempotencyKey;

  Future<void> submit(String bookingId) async {
    if (state is CheckInSubmitting) return;
    emit(const CheckInState.submitting());
    final key = _idempotencyKey ??= newIdempotencyKey();
    final result = await _checkIn(
      CheckInParams(bookingId: bookingId, idempotencyKey: key),
    );
    result.match(
      (failure) {
        // A coded rejection is definitive — the backend stores it as failed_final,
        // so reusing the key would replay the same error. Rotate for the next
        // attempt; keep the key only for ambiguous/transport failures (no code).
        if (failure.code != null) _idempotencyKey = null;
        emit(CheckInState.error(failure.message, code: failure.code));
      },
      (entry) {
        _idempotencyKey = null;
        emit(CheckInState.success(entry));
      },
    );
  }
}
