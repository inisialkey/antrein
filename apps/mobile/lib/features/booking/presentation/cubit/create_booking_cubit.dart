import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/core/utils/idempotency.dart';
import 'package:antrein/features/booking/domain/entities/booking_draft.dart';
import 'package:antrein/features/booking/domain/repositories/booking_repository.dart';
import 'package:antrein/features/booking/domain/usecases/create_booking.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'create_booking_cubit.freezed.dart';
part 'create_booking_state.dart';

/// Submits a booking draft. The Idempotency-Key is created when the logical
/// submission begins and KEPT across retries (backend contract §23) — a
/// provider outage (PAYMENT_PROVIDER_UNAVAILABLE) retries with the same key
/// and resumes the held slot (ADR 0040).
@injectable
class CreateBookingCubit extends Cubit<CreateBookingState> {
  CreateBookingCubit(this._createBooking)
    : super(const CreateBookingState.idle());

  final CreateBooking _createBooking;

  String? _idempotencyKey;

  Future<void> submit(BookingDraft draft) async {
    final slot = draft.slot;
    final staff = draft.staff;
    if (slot == null || staff == null) return;
    _idempotencyKey ??= newIdempotencyKey();

    emit(const CreateBookingState.submitting());
    final result = await _createBooking(
      CreateBookingParams(
        businessId: draft.businessId,
        outletId: draft.outlet.id,
        serviceId: draft.service.id,
        staffId: staff.id,
        scheduledAt: slot.startsAt,
        paymentOption: draft.paymentOption,
        idempotencyKey: _idempotencyKey!,
        notes: draft.notes,
      ),
    );
    result.match(
      (failure) {
        final retryable =
            failure.code == ApiErrorCodes.paymentProviderUnavailable;
        // A definitive rejection ends this logical submission; the next
        // attempt is a new one with a new key.
        if (!retryable) _idempotencyKey = null;
        emit(
          CreateBookingState.error(
            failure.message,
            code: failure.code,
            retryable: retryable,
          ),
        );
      },
      (creation) {
        _idempotencyKey = null;
        emit(CreateBookingState.success(creation));
      },
    );
  }
}
