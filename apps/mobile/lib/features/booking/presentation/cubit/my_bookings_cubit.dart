import 'package:antrein/features/booking/domain/entities/booking.dart';
import 'package:antrein/features/booking/domain/usecases/get_my_bookings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'my_bookings_cubit.freezed.dart';
part 'my_bookings_state.dart';

/// Bookings tab list. Refresh keeps stale data visible (never blanks).
@injectable
class MyBookingsCubit extends Cubit<MyBookingsState> {
  MyBookingsCubit(this._getMyBookings)
    : super(const MyBookingsState(status: MyBookingsStatus.initial));

  final GetMyBookings _getMyBookings;

  Future<void> load() async {
    emit(state.copyWith(status: MyBookingsStatus.loading));
    await _fetch();
  }

  Future<void> refresh() async {
    emit(state.copyWith(isRefreshing: true));
    await _fetch();
  }

  Future<void> _fetch() async {
    final result = await _getMyBookings(const GetMyBookingsParams());
    result.match(
      (failure) => emit(
        state.copyWith(
          status: state.bookings.isEmpty
              ? MyBookingsStatus.failure
              : state.status,
          isRefreshing: false,
          message: failure.message,
        ),
      ),
      (bookings) => emit(
        state.copyWith(
          status: bookings.isEmpty
              ? MyBookingsStatus.empty
              : MyBookingsStatus.success,
          bookings: bookings,
          isRefreshing: false,
          message: null,
        ),
      ),
    );
  }
}
