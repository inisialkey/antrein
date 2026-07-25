import 'package:antrein/features/discovery/domain/entities/business_summary.dart';
import 'package:antrein/features/discovery/domain/usecases/get_businesses.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'discovery_cubit.freezed.dart';
part 'discovery_state.dart';

/// Drives the Home tab's business discovery list. Page-scoped factory.
@injectable
class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit(this._getBusinesses) : super(const DiscoveryState.initial());

  final GetBusinesses _getBusinesses;

  Future<void> load({String? query}) async {
    emit(const DiscoveryState.loading());
    final result = await _getBusinesses(GetBusinessesParams(query: query));
    result.match(
      (failure) => emit(DiscoveryState.error(failure.message)),
      (businesses) => emit(
        businesses.isEmpty
            ? const DiscoveryState.empty()
            : DiscoveryState.loaded(businesses),
      ),
    );
  }

  /// Pull-to-refresh: reload without blanking the current list.
  Future<void> refresh() async {
    final current = state;
    final result = await _getBusinesses(const GetBusinessesParams());
    result.match(
      (failure) {
        // Keep showing stale data on refresh failure; surface only on cold load.
        if (current is! DiscoveryLoaded) {
          emit(DiscoveryState.error(failure.message));
        }
      },
      (businesses) => emit(
        businesses.isEmpty
            ? const DiscoveryState.empty()
            : DiscoveryState.loaded(businesses),
      ),
    );
  }
}
