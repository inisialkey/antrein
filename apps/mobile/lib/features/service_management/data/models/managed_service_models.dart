import 'package:antrein/core/domain/money.dart';
import 'package:antrein/features/service_management/domain/entities/managed_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'managed_service_models.freezed.dart';
part 'managed_service_models.g.dart';

/// Wire models for service management (api-contract §47–§49).

@freezed
abstract class ServiceDepositModel with _$ServiceDepositModel {
  const factory ServiceDepositModel({String? type, int? value}) =
      _ServiceDepositModel;

  factory ServiceDepositModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceDepositModelFromJson(json);
}

@freezed
abstract class ManagedServiceModel with _$ManagedServiceModel {
  const ManagedServiceModel._();

  const factory ManagedServiceModel({
    required String id,
    required String name,
    required int durationMinutes,
    required Money price,
    String? description,
    ServiceDepositModel? deposit,
    @Default(<String>[]) List<String> eligibleStaffIds,
    @Default(true) bool isActive,
  }) = _ManagedServiceModel;

  factory ManagedServiceModel.fromJson(Map<String, dynamic> json) =>
      _$ManagedServiceModelFromJson(json);

  ManagedService toEntity() => ManagedService(
    id: id,
    name: name,
    description: description,
    durationMinutes: durationMinutes,
    price: price,
    // `deposit` is null for a `none` service, so the value carries the type.
    depositValue: deposit?.value ?? 0,
    eligibleStaffIds: eligibleStaffIds,
    isActive: isActive,
  );
}

@freezed
abstract class StaffOptionModel with _$StaffOptionModel {
  const StaffOptionModel._();

  const factory StaffOptionModel({required String id, required String name}) =
      _StaffOptionModel;

  factory StaffOptionModel.fromJson(Map<String, dynamic> json) =>
      _$StaffOptionModelFromJson(json);

  StaffOption toEntity() => StaffOption(id: id, name: name);
}
