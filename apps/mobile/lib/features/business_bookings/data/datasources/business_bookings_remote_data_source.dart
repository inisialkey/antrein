import 'package:antrein/core/domain/money.dart';
import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/booking/data/models/booking_models.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class BusinessBookingsRemoteDataSource {
  Future<List<BookingModel>> list({
    required String businessId,
    required String outletId,
    required String date,
  });

  Future<void> confirmPayAtLocation({
    required String businessId,
    required String bookingId,
    required Money amount,
    required String method,
    required String idempotencyKey,
    String? note,
  });

  Future<void> cancel({
    required String businessId,
    required String bookingId,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  });

  Future<void> markNoShow({
    required String businessId,
    required String bookingId,
    required String idempotencyKey,
    String? reason,
  });

  Future<List<PaymentModel>> listPayments(String bookingId);

  Future<void> requestRefund({
    required String businessId,
    required String paymentId,
    required Money amount,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  });
}

@LazySingleton(as: BusinessBookingsRemoteDataSource)
class BusinessBookingsRemoteDataSourceImpl
    implements BusinessBookingsRemoteDataSource {
  const BusinessBookingsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<BookingModel>> list({
    required String businessId,
    required String outletId,
    required String date,
  }) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.businessBookings(businessId),
        // ponytail: one outlet-day, single page. A barbershop day fits well
        // under the 100 max; wire the cursor when a day overflows it.
        queryParameters: {'outletId': outletId, 'date': date, 'limit': 100},
      ),
    );
    return ((data['items'] as List<dynamic>?) ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => BookingModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> confirmPayAtLocation({
    required String businessId,
    required String bookingId,
    required Money amount,
    required String method,
    required String idempotencyKey,
    String? note,
  }) async {
    await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.payAtLocationConfirm(businessId, bookingId),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {
          'amount': amount.toJson(),
          'method': method,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      ),
    );
  }

  @override
  Future<void> cancel({
    required String businessId,
    required String bookingId,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  }) async {
    await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.businessBookingCancel(businessId, bookingId),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {'reasonCode': reasonCode, 'reason': reason},
      ),
    );
  }

  @override
  Future<void> markNoShow({
    required String businessId,
    required String bookingId,
    required String idempotencyKey,
    String? reason,
  }) async {
    await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.businessBookingNoShow(businessId, bookingId),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      ),
    );
  }

  @override
  Future<List<PaymentModel>> listPayments(String bookingId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(ApiEndpoints.bookingPayments(bookingId)),
    );
    return ((data['items'] as List<dynamic>?) ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => PaymentModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> requestRefund({
    required String businessId,
    required String paymentId,
    required Money amount,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  }) async {
    await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.paymentRefunds(businessId, paymentId),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {
          'amount': amount.toJson(),
          'reasonCode': reasonCode,
          'reason': reason,
        },
      ),
    );
  }
}
