import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/business_management/data/models/managed_business_models.dart';
import 'package:antrein/features/business_management/domain/entities/managed_business.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class BusinessManagementRemoteDataSource {
  Future<ManagedBusinessModel> getManagement(String businessId);

  Future<void> updateBusiness(String businessId, ManagedBusiness business);

  Future<ManagedOutlet?> getOutlet(String businessId, String outletId);

  Future<void> updateOutlet(String businessId, ManagedOutlet outlet);

  Future<void> createBusiness({
    required String name,
    required String outletName,
    required String address,
    required String idempotencyKey,
    String? description,
    String? phoneNumber,
  });
}

@LazySingleton(as: BusinessManagementRemoteDataSource)
class BusinessManagementRemoteDataSourceImpl
    implements BusinessManagementRemoteDataSource {
  const BusinessManagementRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<ManagedBusinessModel> getManagement(String businessId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(ApiEndpoints.businessManagement(businessId)),
    );
    return ManagedBusinessModel.fromJson(data);
  }

  @override
  Future<void> updateBusiness(
    String businessId,
    ManagedBusiness business,
  ) => sendEnvelope(
    () => _dio.patch<dynamic>(
      ApiEndpoints.businessDetail(businessId),
      data: {
        'name': business.name,
        'description': business.description,
        'supportedPaymentOptions': business.supportedPaymentOptions,
        'bookingPolicy': {
          'minimumLeadMinutes': business.bookingPolicy.minimumLeadMinutes,
          'maximumAdvanceDays': business.bookingPolicy.maximumAdvanceDays,
          'automaticConfirmation': business.bookingPolicy.automaticConfirmation,
        },
        // `enabled` is authoritative on the backend and overrides the deposit
        // entry in supportedPaymentOptions — the form keeps the two in step.
        'depositPolicy': {
          'enabled': business.allows(depositOption),
          'defaultType': business.defaultDepositValue > 0 ? 'fixed' : 'none',
          'defaultValue': business.defaultDepositValue,
        },
        'cancellationPolicy': {
          'fullRefundBeforeMinutes':
              business.cancellationPolicy.fullRefundBeforeMinutes,
          'partialRefundBeforeMinutes':
              business.cancellationPolicy.partialRefundBeforeMinutes,
          'partialRefundPercentage':
              business.cancellationPolicy.partialRefundPercentage,
          'noShowRefundPercentage':
              business.cancellationPolicy.noShowRefundPercentage,
        },
      },
    ),
  );

  /// There is no management read for a single outlet, so the public §39 detail
  /// supplies the current values the form prefills from.
  @override
  Future<ManagedOutlet?> getOutlet(String businessId, String outletId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(ApiEndpoints.businessDetail(businessId)),
    );
    final outlets = ((data['outlets'] as List<dynamic>?) ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => e.cast<String, dynamic>());
    for (final outlet in outlets) {
      if (outlet['id'] == outletId) {
        final address = (outlet['address'] as Map<dynamic, dynamic>?)
            ?.cast<String, dynamic>();
        return ManagedOutlet(
          id: outletId,
          name: outlet['name'] as String? ?? '',
          phoneNumber: outlet['phoneNumber'] as String?,
          address: address?['formatted'] as String?,
        );
      }
    }
    return null;
  }

  @override
  Future<void> updateOutlet(String businessId, ManagedOutlet outlet) =>
      sendEnvelope(
        () => _dio.patch<dynamic>(
          ApiEndpoints.outletDetail(businessId, outlet.id),
          data: {
            'name': outlet.name,
            'phoneNumber': outlet.phoneNumber,
            // `address.formatted` is required whenever address is present, so
            // an empty one is left out rather than sent as null.
            if (outlet.address != null && outlet.address!.isNotEmpty)
              'address': {'formatted': outlet.address},
          },
        ),
      );

  @override
  Future<void> createBusiness({
    required String name,
    required String outletName,
    required String address,
    required String idempotencyKey,
    String? description,
    String? phoneNumber,
  }) => sendEnvelope(
    () => _dio.post<dynamic>(
      ApiEndpoints.businesses,
      data: {
        'name': name,
        'description': ?description,
        'primaryOutlet': {
          'name': outletName,
          'phoneNumber': ?phoneNumber,
          'address': {'formatted': address},
        },
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
  );
}
