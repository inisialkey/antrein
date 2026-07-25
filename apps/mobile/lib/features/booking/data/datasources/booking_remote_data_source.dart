import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/booking/data/models/booking_models.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class BookingRemoteDataSource {
  Future<List<SlotModel>> getAvailability({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String staffId,
    required String date,
  });

  Future<({BookingModel booking, PaymentModel? payment})> createBooking({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String staffId,
    required String scheduledAt,
    required String paymentOption,
    required String idempotencyKey,
    String? notes,
  });

  Future<List<BookingModel>> listMyBookings({String? status});

  Future<BookingModel> getBooking(String bookingId);

  Future<void> cancelBooking({
    required String bookingId,
    required String idempotencyKey,
    String? reasonCode,
    String? reason,
  });

  Future<({String paymentStatus, String bookingStatus, bool refreshed})>
  refreshPayment(String paymentId);

  Future<List<PaymentModel>> listBookingPayments(String bookingId);
}

@LazySingleton(as: BookingRemoteDataSource)
class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  const BookingRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<SlotModel>> getAvailability({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String staffId,
    required String date,
  }) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.businessAvailability(businessId),
        queryParameters: {
          'outletId': outletId,
          'serviceId': serviceId,
          'staffId': staffId,
          'date': date,
        },
      ),
    );
    return ((data['slots'] as List<dynamic>?) ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => SlotModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<({BookingModel booking, PaymentModel? payment})> createBooking({
    required String businessId,
    required String outletId,
    required String serviceId,
    required String staffId,
    required String scheduledAt,
    required String paymentOption,
    required String idempotencyKey,
    String? notes,
  }) async {
    final data = await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.bookings,
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {
          'businessId': businessId,
          'outletId': outletId,
          'serviceId': serviceId,
          'staffSelection': {'mode': 'specific_staff', 'staffId': staffId},
          'scheduledAt': scheduledAt,
          'paymentOption': paymentOption,
          if (notes != null && notes.isNotEmpty) 'customerNotes': notes,
        },
      ),
    );
    final bookingJson = (data['booking'] as Map?)?.cast<String, dynamic>();
    final paymentJson = (data['payment'] as Map?)?.cast<String, dynamic>();
    return (
      booking: BookingModel.fromJson(bookingJson ?? data),
      payment: paymentJson == null ? null : PaymentModel.fromJson(paymentJson),
    );
  }

  @override
  Future<List<BookingModel>> listMyBookings({String? status}) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.bookings,
        queryParameters: {'status': ?status, 'limit': 50},
      ),
    );
    return ((data['items'] as List<dynamic>?) ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => BookingModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<BookingModel> getBooking(String bookingId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(ApiEndpoints.bookingDetail(bookingId)),
    );
    return BookingModel.fromJson(data);
  }

  @override
  Future<void> cancelBooking({
    required String bookingId,
    required String idempotencyKey,
    String? reasonCode,
    String? reason,
  }) async {
    await sendEnvelope(
      () => _dio.post<dynamic>(
        ApiEndpoints.bookingCancel(bookingId),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        data: {
          'reasonCode': ?reasonCode,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      ),
    );
  }

  @override
  Future<({String paymentStatus, String bookingStatus, bool refreshed})>
  refreshPayment(String paymentId) async {
    final data = await sendEnvelope(
      () => _dio.post<dynamic>(ApiEndpoints.paymentRefresh(paymentId)),
    );
    final payment = (data['payment'] as Map?)?.cast<String, dynamic>();
    return (
      paymentStatus: payment?['status'] as String? ?? 'pending',
      bookingStatus: data['bookingStatus'] as String? ?? 'pending_payment',
      refreshed: data['refreshedFromProvider'] as bool? ?? false,
    );
  }

  @override
  Future<List<PaymentModel>> listBookingPayments(String bookingId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        '${ApiEndpoints.bookingDetail(bookingId)}/payments',
      ),
    );
    return ((data['items'] as List<dynamic>?) ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => PaymentModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
