import 'package:antrein/features/business_management/domain/entities/managed_business.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'managed_business_models.freezed.dart';
part 'managed_business_models.g.dart';

/// Wire models for business management (api-contract §43–§46).

@freezed
abstract class BookingPolicyModel with _$BookingPolicyModel {
  const factory BookingPolicyModel({
    int? minimumLeadMinutes,
    int? maximumAdvanceDays,
    bool? automaticConfirmation,
  }) = _BookingPolicyModel;

  factory BookingPolicyModel.fromJson(Map<String, dynamic> json) =>
      _$BookingPolicyModelFromJson(json);
}

@freezed
abstract class DepositPolicyModel with _$DepositPolicyModel {
  const factory DepositPolicyModel({bool? enabled, int? defaultValue}) =
      _DepositPolicyModel;

  factory DepositPolicyModel.fromJson(Map<String, dynamic> json) =>
      _$DepositPolicyModelFromJson(json);
}

@freezed
abstract class CancellationPolicyModel with _$CancellationPolicyModel {
  const factory CancellationPolicyModel({
    int? fullRefundBeforeMinutes,
    int? partialRefundBeforeMinutes,
    int? partialRefundPercentage,
    int? noShowRefundPercentage,
  }) = _CancellationPolicyModel;

  factory CancellationPolicyModel.fromJson(Map<String, dynamic> json) =>
      _$CancellationPolicyModelFromJson(json);
}

@freezed
abstract class ManagedBusinessModel with _$ManagedBusinessModel {
  const ManagedBusinessModel._();

  const factory ManagedBusinessModel({
    required String id,
    required String name,
    String? description,
    String? logoUrl,
    @Default(<String>[]) List<String> supportedPaymentOptions,
    BookingPolicyModel? bookingPolicy,
    DepositPolicyModel? depositPolicy,
    CancellationPolicyModel? cancellationPolicy,
  }) = _ManagedBusinessModel;

  factory ManagedBusinessModel.fromJson(Map<String, dynamic> json) =>
      _$ManagedBusinessModelFromJson(json);

  ManagedBusiness toEntity() {
    const bookingDefaults = BookingPolicy();
    const cancellationDefaults = CancellationPolicy();
    final booking = bookingPolicy;
    final cancellation = cancellationPolicy;
    return ManagedBusiness(
      id: id,
      name: name,
      description: description,
      logoUrl: logoUrl,
      supportedPaymentOptions: supportedPaymentOptions,
      bookingPolicy: BookingPolicy(
        minimumLeadMinutes:
            booking?.minimumLeadMinutes ?? bookingDefaults.minimumLeadMinutes,
        maximumAdvanceDays:
            booking?.maximumAdvanceDays ?? bookingDefaults.maximumAdvanceDays,
        automaticConfirmation:
            booking?.automaticConfirmation ??
            bookingDefaults.automaticConfirmation,
      ),
      cancellationPolicy: CancellationPolicy(
        fullRefundBeforeMinutes:
            cancellation?.fullRefundBeforeMinutes ??
            cancellationDefaults.fullRefundBeforeMinutes,
        partialRefundBeforeMinutes:
            cancellation?.partialRefundBeforeMinutes ??
            cancellationDefaults.partialRefundBeforeMinutes,
        partialRefundPercentage:
            cancellation?.partialRefundPercentage ??
            cancellationDefaults.partialRefundPercentage,
        noShowRefundPercentage:
            cancellation?.noShowRefundPercentage ??
            cancellationDefaults.noShowRefundPercentage,
      ),
      defaultDepositValue: depositPolicy?.defaultValue ?? 0,
    );
  }
}
