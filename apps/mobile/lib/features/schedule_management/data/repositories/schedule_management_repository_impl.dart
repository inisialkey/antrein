import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/schedule_management/data/datasources/schedule_remote_data_source.dart';
import 'package:antrein/features/schedule_management/domain/entities/weekly_schedule.dart';
import 'package:antrein/features/schedule_management/domain/repositories/schedule_management_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ScheduleManagementRepository)
class ScheduleManagementRepositoryImpl implements ScheduleManagementRepository {
  const ScheduleManagementRepositoryImpl(this._remote);

  final ScheduleRemoteDataSource _remote;

  @override
  ResultFuture<OperatingHours> getOperatingHours(
    String businessId,
    String outletId,
  ) async {
    try {
      return Right(await _remote.getOperatingHours(businessId, outletId));
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'getOperatingHours'));
    }
  }

  @override
  ResultVoid replaceOperatingHours(
    String businessId,
    String outletId,
    OperatingHours hours,
  ) async {
    try {
      await _remote.replaceOperatingHours(businessId, outletId, hours);
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'replaceOperatingHours'));
    }
  }

  @override
  ResultFuture<List<ClosedDate>> listClosedDates(
    String businessId,
    String outletId, {
    String? dateFrom,
  }) async {
    try {
      return Right(
        await _remote.listClosedDates(
          businessId,
          outletId,
          dateFrom: dateFrom,
        ),
      );
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'listClosedDates'));
    }
  }

  @override
  ResultVoid createClosedDate(
    String businessId,
    String outletId, {
    required String date,
    required String idempotencyKey,
    String? reason,
  }) async {
    try {
      await _remote.createClosedDate(
        businessId,
        outletId,
        date: date,
        idempotencyKey: idempotencyKey,
        reason: reason,
      );
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'createClosedDate'));
    }
  }

  @override
  ResultFuture<StaffSchedule> getStaffSchedule(
    String businessId,
    String staffId,
  ) async {
    try {
      return Right(await _remote.getStaffSchedule(businessId, staffId));
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'getStaffSchedule'));
    }
  }

  @override
  ResultVoid replaceStaffSchedule(
    String businessId,
    StaffSchedule schedule,
  ) async {
    try {
      await _remote.replaceStaffSchedule(businessId, schedule);
      return const Right(null);
    } on Exception catch (e) {
      return Left(mapExceptionToFailure(e, 'replaceStaffSchedule'));
    }
  }
}
