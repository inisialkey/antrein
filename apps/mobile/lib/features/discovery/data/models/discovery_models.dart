import 'package:antrein/core/domain/money.dart';
import 'package:antrein/features/discovery/domain/entities/business_detail.dart';
import 'package:antrein/features/discovery/domain/entities/business_summary.dart';
import 'package:antrein/features/discovery/domain/entities/service_item.dart';
import 'package:antrein/features/discovery/domain/entities/staff_member.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'discovery_models.freezed.dart';
part 'discovery_models.g.dart';

/// Wire models for public discovery (api-contract §38–§41). Field names match
/// the camelCase contract; unknown fields are ignored.

@freezed
abstract class RatingModel with _$RatingModel {
  const factory RatingModel({double? average, int? count}) = _RatingModel;

  factory RatingModel.fromJson(Map<String, dynamic> json) =>
      _$RatingModelFromJson(json);
}

@freezed
abstract class AddressModel with _$AddressModel {
  const factory AddressModel({String? formatted}) = _AddressModel;

  factory AddressModel.fromJson(Map<String, dynamic> json) =>
      _$AddressModelFromJson(json);
}

@freezed
abstract class OutletSummaryModel with _$OutletSummaryModel {
  const factory OutletSummaryModel({
    required String id,
    required String name,
    AddressModel? address,
    bool? isOpenNow,
    String? phoneNumber,
  }) = _OutletSummaryModel;

  factory OutletSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$OutletSummaryModelFromJson(json);
}

@freezed
abstract class PriceRangeModel with _$PriceRangeModel {
  const factory PriceRangeModel({Money? minimum, Money? maximum}) =
      _PriceRangeModel;

  factory PriceRangeModel.fromJson(Map<String, dynamic> json) =>
      _$PriceRangeModelFromJson(json);
}

@freezed
abstract class BusinessSummaryModel with _$BusinessSummaryModel {
  const BusinessSummaryModel._();

  const factory BusinessSummaryModel({
    required String id,
    required String name,
    String? logoUrl,
    RatingModel? rating,
    OutletSummaryModel? primaryOutlet,
    PriceRangeModel? priceRange,
    @Default(<String>[]) List<String> supportedPaymentOptions,
  }) = _BusinessSummaryModel;

  factory BusinessSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessSummaryModelFromJson(json);

  BusinessSummary toEntity() => BusinessSummary(
    id: id,
    name: name,
    logoUrl: logoUrl,
    ratingAverage: rating?.average,
    ratingCount: rating?.count,
    outletId: primaryOutlet?.id,
    outletName: primaryOutlet?.name,
    address: primaryOutlet?.address?.formatted,
    isOpenNow: primaryOutlet?.isOpenNow,
    minimumPrice: priceRange?.minimum,
    supportedPaymentOptions: supportedPaymentOptions,
  );
}

@freezed
abstract class CancellationPolicyModel with _$CancellationPolicyModel {
  const factory CancellationPolicyModel({String? summary}) =
      _CancellationPolicyModel;

  factory CancellationPolicyModel.fromJson(Map<String, dynamic> json) =>
      _$CancellationPolicyModelFromJson(json);
}

@freezed
abstract class BusinessDetailModel with _$BusinessDetailModel {
  const BusinessDetailModel._();

  const factory BusinessDetailModel({
    required String id,
    required String name,
    String? description,
    String? logoUrl,
    RatingModel? rating,
    CancellationPolicyModel? cancellationPolicy,
    @Default(<String>[]) List<String> supportedPaymentOptions,
    @Default(<OutletSummaryModel>[]) List<OutletSummaryModel> outlets,
  }) = _BusinessDetailModel;

  factory BusinessDetailModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessDetailModelFromJson(json);

  BusinessDetail toEntity() => BusinessDetail(
    id: id,
    name: name,
    description: description,
    logoUrl: logoUrl,
    ratingAverage: rating?.average,
    ratingCount: rating?.count,
    cancellationPolicySummary: cancellationPolicy?.summary,
    supportedPaymentOptions: supportedPaymentOptions,
    outlets: outlets
        .map(
          (o) => OutletInfo(
            id: o.id,
            name: o.name,
            address: o.address?.formatted,
            phoneNumber: o.phoneNumber,
          ),
        )
        .toList(growable: false),
  );
}

@freezed
abstract class DepositModel with _$DepositModel {
  const factory DepositModel({
    String? type,
    int? value,
    Money? requiredAmount,
  }) = _DepositModel;

  factory DepositModel.fromJson(Map<String, dynamic> json) =>
      _$DepositModelFromJson(json);
}

@freezed
abstract class ServiceModel with _$ServiceModel {
  const ServiceModel._();

  const factory ServiceModel({
    required String id,
    required String name,
    required int durationMinutes,
    required Money price,
    String? description,
    String? imageUrl,
    DepositModel? deposit,
    @Default(true) bool isActive,
  }) = _ServiceModel;

  factory ServiceModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceModelFromJson(json);

  ServiceItem toEntity() => ServiceItem(
    id: id,
    name: name,
    description: description,
    imageUrl: imageUrl,
    durationMinutes: durationMinutes,
    price: price,
    depositAmount: deposit?.type == 'fixed' ? deposit?.requiredAmount : null,
    isActive: isActive,
  );
}

@freezed
abstract class StaffModel with _$StaffModel {
  const StaffModel._();

  const factory StaffModel({
    required String id,
    required String name,
    String? avatarUrl,
    RatingModel? rating,
    @Default(<String>[]) List<String> eligibleServiceIds,
    @Default(true) bool isActive,
  }) = _StaffModel;

  factory StaffModel.fromJson(Map<String, dynamic> json) =>
      _$StaffModelFromJson(json);

  StaffMember toEntity() => StaffMember(
    id: id,
    name: name,
    avatarUrl: avatarUrl,
    ratingAverage: rating?.average,
    eligibleServiceIds: eligibleServiceIds,
    isActive: isActive,
  );
}
