import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/schedule_management/domain/entities/weekly_schedule.dart';

abstract class ScheduleManagementRepository {
  /// §54.
  ResultFuture<OperatingHours> getOperatingHours(
    String businessId,
    String outletId,
  );

  /// §55 — a full-week replace; anything not sent is dropped.
  ResultVoid replaceOperatingHours(
    String businessId,
    String outletId,
    OperatingHours hours,
  );

  /// §56.
  ResultFuture<List<ClosedDate>> listClosedDates(
    String businessId,
    String outletId, {
    String? dateFrom,
  });

  /// §57.
  ResultVoid createClosedDate(
    String businessId,
    String outletId, {
    required String date,
    required String idempotencyKey,
    String? reason,
  });

  /// §58.
  ResultFuture<StaffSchedule> getStaffSchedule(
    String businessId,
    String staffId,
  );

  /// §58.1 — also a full-week replace.
  ResultVoid replaceStaffSchedule(String businessId, StaffSchedule schedule);
}
