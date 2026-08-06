import 'package:antrein/core/error/failures.dart';
import 'package:antrein/features/business_management/domain/entities/managed_business.dart';
import 'package:antrein/features/business_management/domain/repositories/business_management_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'business_settings_state.dart';
part 'business_settings_cubit.freezed.dart';

/// Business profile, policies and the primary outlet (api-contract §44–§46,
/// ui-feature-spec §38). The state holds the editable copy; one save writes
/// the business first, then the outlet.
@injectable
class BusinessSettingsCubit extends Cubit<BusinessSettingsState> {
  BusinessSettingsCubit(this._repo) : super(const BusinessSettingsState());

  final BusinessManagementRepository _repo;

  late String _businessId;
  late String _outletId;

  Future<void> load(String businessId, String outletId) async {
    _businessId = businessId;
    _outletId = outletId;
    emit(state.copyWith(status: SettingsStatus.loading, message: null));

    final businessResult = await _repo.getManagement(businessId);
    if (isClosed) return;
    final business = businessResult.match<ManagedBusiness?>(
      (_) => null,
      (value) => value,
    );
    if (business == null) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          message: businessResult.match((f) => f.message, (_) => null),
        ),
      );
      return;
    }

    // The outlet section is optional context — if the public detail read fails
    // the policies are still editable, the outlet fields just stay empty.
    final outletResult = await _repo.getOutlet(businessId, outletId);
    if (isClosed) return;

    emit(
      state.copyWith(
        status: SettingsStatus.success,
        business: business,
        outlet: outletResult.match((_) => null, (value) => value),
      ),
    );
  }

  /// §45 then §46 — both need `business.manage`, so they share one action.
  /// The outlet write is skipped when the outlet never loaded.
  Future<void> save({
    required ManagedBusiness business,
    ManagedOutlet? outlet,
  }) async {
    if (state.isSaving) return;
    emit(state.copyWith(isSaving: true, message: null));

    var failure = (await _repo.updateBusiness(
      _businessId,
      business,
    )).match<Failure?>((f) => f, (_) => null);

    if (failure == null && outlet != null) {
      failure = (await _repo.updateOutlet(
        _businessId,
        ManagedOutlet(
          id: _outletId,
          name: outlet.name,
          phoneNumber: outlet.phoneNumber,
          address: outlet.address,
        ),
      )).match<Failure?>((f) => f, (_) => null);
    }
    if (isClosed) return;

    emit(
      state.copyWith(
        isSaving: false,
        business: failure == null ? business : state.business,
        outlet: failure == null ? outlet : state.outlet,
        message: failure?.message,
        savedTick: failure == null ? state.savedTick + 1 : state.savedTick,
      ),
    );
  }
}
