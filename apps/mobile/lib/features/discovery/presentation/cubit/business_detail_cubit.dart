import 'package:antrein/features/discovery/domain/usecases/get_business_profile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'business_detail_cubit.freezed.dart';
part 'business_detail_state.dart';

/// Loads the business profile (detail + services + staff). Page-scoped factory.
@injectable
class BusinessDetailCubit extends Cubit<BusinessDetailState> {
  BusinessDetailCubit(this._getProfile)
    : super(const BusinessDetailState.initial());

  final GetBusinessProfile _getProfile;

  Future<void> load(String businessId) async {
    emit(const BusinessDetailState.loading());
    final result = await _getProfile(
      GetBusinessProfileParams(businessId: businessId),
    );
    result.match(
      (failure) => emit(BusinessDetailState.error(failure.message)),
      (profile) => emit(BusinessDetailState.loaded(profile)),
    );
  }
}
