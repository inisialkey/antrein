import 'dart:math';

import 'package:antrein/core/network/api_error_codes.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/booking.dart';
import 'package:antrein/features/business_bookings/domain/repositories/business_bookings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';

part 'business_bookings_state.dart';
part 'business_bookings_cubit.freezed.dart';

/// Drives the operational booking desk (contract §65, §68, §68.1, §73): one
/// outlet-day of bookings plus the three counter actions. Every mutation
/// re-reads the list — REST stays authoritative, exactly like the queue board.
///
/// ponytail: the cubit calls the repository directly; four one-line use-case
/// wrappers would be pure boilerplate (same call as `StaffQueueCubit`).
@injectable
class BusinessBookingsCubit extends Cubit<BusinessBookingsState> {
  BusinessBookingsCubit(this._repo) : super(const BusinessBookingsState());

  static final DateFormat _businessDate = DateFormat('yyyy-MM-dd');

  final BusinessBookingsRepository _repo;
  String? _businessId;
  String? _outletId;

  /// One key per logical submission, kept across transport retries and rotated
  /// after a coded rejection (CLAUDE.md idempotency rule). Keyed by
  /// `action:bookingId` so a cancel never replays a payment's key.
  final Map<String, String> _keys = {};

  Future<void> load({
    required String businessId,
    required String outletId,
    DateTime? date,
  }) async {
    _businessId = businessId;
    _outletId = outletId;
    emit(
      state.copyWith(
        status: BookingDeskStatus.loading,
        date: date ?? DateTime.now(),
        message: null,
      ),
    );
    await _fetch(silent: false);
  }

  Future<void> refresh() => _fetch(silent: true);

  Future<void> changeDate(DateTime date) async {
    emit(state.copyWith(date: date, status: BookingDeskStatus.loading));
    await _fetch(silent: false);
  }

  Future<void> _fetch({required bool silent}) async {
    final businessId = _businessId;
    final outletId = _outletId;
    final date = state.date;
    if (businessId == null || outletId == null || date == null) return;
    if (silent) emit(state.copyWith(isRefreshing: true));

    final result = await _repo.list(
      businessId: businessId,
      outletId: outletId,
      date: _businessDate.format(date),
    );
    result.match(
      (failure) => emit(
        silent
            // A background refresh failure keeps the last-known list on screen.
            ? state.copyWith(isRefreshing: false)
            : state.copyWith(
                status: BookingDeskStatus.failure,
                isRefreshing: false,
                message: failure.message,
              ),
      ),
      (bookings) => emit(
        state.copyWith(
          status: bookings.isEmpty
              ? BookingDeskStatus.empty
              : BookingDeskStatus.success,
          bookings: bookings,
          isRefreshing: false,
          message: null,
        ),
      ),
    );
  }

  /// Records counter payment (§73). The amount is never typed — it is the
  /// booking's outstanding balance, the only figure the backend accepts.
  Future<void> confirmPayment({
    required Booking booking,
    required String method,
    String? note,
  }) => _act(booking, BookingDeskAction.paymentConfirmed, (key) {
    final businessId = _businessId!;
    return _repo.confirmPayAtLocation(
      businessId: businessId,
      bookingId: booking.id,
      amount: booking.outstanding,
      method: method,
      idempotencyKey: key,
      note: note,
    );
  });

  Future<void> cancelBooking({
    required Booking booking,
    required String reasonCode,
    required String reason,
  }) => _act(booking, BookingDeskAction.cancelled, (key) {
    final businessId = _businessId!;
    return _repo.cancel(
      businessId: businessId,
      bookingId: booking.id,
      reasonCode: reasonCode,
      reason: reason,
      idempotencyKey: key,
    );
  });

  Future<void> markNoShow({required Booking booking, String? reason}) =>
      _act(booking, BookingDeskAction.noShow, (key) {
        final businessId = _businessId!;
        return _repo.markNoShow(
          businessId: businessId,
          bookingId: booking.id,
          idempotencyKey: key,
          reason: reason,
        );
      });

  /// Shared mutation shell: one action at a time, resync afterwards either way.
  Future<void> _act(
    Booking booking,
    BookingDeskAction action,
    ResultVoid Function(String idempotencyKey) run,
  ) async {
    if (_businessId == null || state.actingBookingId != null) return;
    emit(
      state.copyWith(
        actingBookingId: booking.id,
        actionError: null,
        actionDone: null,
      ),
    );

    final keyId = '${action.name}:${booking.id}';
    final result = await run(_keys[keyId] ??= _newKey());
    await result.match(
      (failure) async {
        if (failure.code != null) _keys.remove(keyId);
        emit(
          state.copyWith(actingBookingId: null, actionError: failure.message),
        );
        // A stale outstanding figure is the common §73 rejection — resync so the
        // sheet shows what the counter actually owes before the next attempt.
        if (failure.code == ApiErrorCodes.paymentAmountMismatch ||
            failure.code == ApiErrorCodes.paymentAlreadyPaid) {
          await _fetch(silent: true);
        }
      },
      (_) async {
        _keys.remove(keyId);
        emit(state.copyWith(actingBookingId: null, actionDone: action));
        await _fetch(silent: true);
      },
    );
  }

  static String _newKey() {
    final random = Random();
    return 'idem_${DateTime.now().microsecondsSinceEpoch}_'
        '${random.nextInt(1 << 32).toRadixString(16)}';
  }
}
