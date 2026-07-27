import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/features/discovery/data/models/discovery_models.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class DiscoveryRemoteDataSource {
  Future<List<BusinessSummaryModel>> listBusinesses({String? query});

  Future<BusinessDetailModel> getBusiness(String businessId);

  Future<List<ServiceModel>> listServices(String businessId);

  Future<List<StaffModel>> listStaff(String businessId, {String? serviceId});
}

@LazySingleton(as: DiscoveryRemoteDataSource)
class DiscoveryRemoteDataSourceImpl implements DiscoveryRemoteDataSource {
  const DiscoveryRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<BusinessSummaryModel>> listBusinesses({String? query}) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.businesses,
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query,
          'limit': 50,
        },
      ),
    );
    return _items(data).map(BusinessSummaryModel.fromJson).toList();
  }

  @override
  Future<BusinessDetailModel> getBusiness(String businessId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(ApiEndpoints.businessDetail(businessId)),
    );
    return BusinessDetailModel.fromJson(data);
  }

  @override
  Future<List<ServiceModel>> listServices(String businessId) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.businessServices(businessId),
        queryParameters: {'activeOnly': true, 'limit': 100},
      ),
    );
    return _items(data).map(ServiceModel.fromJson).toList();
  }

  @override
  Future<List<StaffModel>> listStaff(
    String businessId, {
    String? serviceId,
  }) async {
    final data = await sendEnvelope(
      () => _dio.get<dynamic>(
        ApiEndpoints.businessStaff(businessId),
        queryParameters: {
          'activeOnly': true,
          'limit': 100,
          'serviceId': ?serviceId,
        },
      ),
    );
    return _items(data).map(StaffModel.fromJson).toList();
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) =>
      ((data['items'] as List<dynamic>?) ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
}
