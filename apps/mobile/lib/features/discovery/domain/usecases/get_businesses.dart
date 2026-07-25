import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/discovery/domain/entities/business_summary.dart';
import 'package:antrein/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class GetBusinesses
    extends UseCase<List<BusinessSummary>, GetBusinessesParams> {
  const GetBusinesses(this._repository);

  final DiscoveryRepository _repository;

  @override
  ResultFuture<List<BusinessSummary>> call(GetBusinessesParams params) =>
      _repository.listBusinesses(query: params.query);
}

class GetBusinessesParams extends Equatable {
  const GetBusinessesParams({this.query});

  final String? query;

  @override
  List<Object?> get props => [query];
}
