import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/schedule_management/data/models/schedule_mappers.dart';
import 'package:antrein/features/schedule_management/domain/entities/weekly_schedule.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class ScheduleRemoteDataSource {
  Future<OperatingHours> getOperatingHours(String businessId, String outletId);

  Future<void> replaceOperatingHours(
    String businessId,
    String outletId,
    OperatingHours hours,
  );

  Future<List<ClosedDate>> listClosedDates(
    String businessId,
    String outletId, {
    String? dateFrom,
  });

  Future<void> createClosedDate(
    String businessId,
    String outletId, {
    required String date,
    required String idempotencyKey,
    String? reason,
  });

  Future<StaffSchedule> getStaffSchedule(String businessId, String staffId);

  Future<void> replaceStaffSchedule(String businessId, StaffSchedule schedule);
}

@LazySingleton(as: ScheduleRemoteDataSource)
class ScheduleRemoteDataSourceImpl implements ScheduleRemoteDataSource {
  const ScheduleRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<OperatingHours> getOperatingHours(
    String businessId,
    String outletId,
  ) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.operatingHours(businessId, outletId),
      ),
    );
    return operatingHoursFromJson(data);
  }

  @override
  Future<void> replaceOperatingHours(
    String businessId,
    String outletId,
    OperatingHours hours,
  ) => sendEnvelope(
    () => _dio.put<dynamic>(
      ApiEndpoints.operatingHours(businessId, outletId),
      data: operatingHoursToJson(hours),
    ),
  );

  @override
  Future<List<ClosedDate>> listClosedDates(
    String businessId,
    String outletId, {
    String? dateFrom,
  }) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.closedDates(businessId, outletId),
        queryParameters: {'dateFrom': ?dateFrom},
      ),
    );
    return closedDatesFromJson(data);
  }

  @override
  Future<void> createClosedDate(
    String businessId,
    String outletId, {
    required String date,
    required String idempotencyKey,
    String? reason,
  }) => sendEnvelope(
    () => _dio.post<dynamic>(
      ApiEndpoints.closedDates(businessId, outletId),
      data: {'date': date, 'reason': ?reason},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
  );

  @override
  Future<StaffSchedule> getStaffSchedule(
    String businessId,
    String staffId,
  ) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(ApiEndpoints.staffSchedule(businessId, staffId)),
    );
    return staffScheduleFromJson(data);
  }

  @override
  Future<void> replaceStaffSchedule(
    String businessId,
    StaffSchedule schedule,
  ) => sendEnvelope(
    () => _dio.put<dynamic>(
      ApiEndpoints.staffSchedule(businessId, schedule.staffId),
      data: staffScheduleToJson(schedule),
    ),
  );
}
