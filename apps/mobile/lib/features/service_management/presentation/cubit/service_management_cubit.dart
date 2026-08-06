import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/files/file_upload_repository.dart';
import 'package:antrein/core/utils/idempotency.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/service_management/domain/entities/managed_service.dart';
import 'package:antrein/features/service_management/domain/repositories/service_management_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'service_management_state.dart';
part 'service_management_cubit.freezed.dart';

/// The owner's service catalog (api-contract §47–§49).
///
/// ponytail: talks to the repository directly — one-line use-case wrappers per
/// call would be pure boilerplate here, same as `NotificationsCubit`.
@injectable
class ServiceManagementCubit extends Cubit<ServiceManagementState> {
  ServiceManagementCubit(this._repo, this._files)
    : super(const ServiceManagementState());

  final ServiceManagementRepository _repo;
  final FileUploadRepository _files;
  late String _businessId;

  /// Held across transport retries of one create, dropped once the backend
  /// answers — a stored key replays the stored outcome (§23.2).
  String? _createKey;

  Future<void> load(String businessId) async {
    _businessId = businessId;
    emit(state.copyWith(status: ServiceListStatus.loading, message: null));
    await _fetch(silent: false);
  }

  Future<void> refresh() => _fetch(silent: true);

  /// Uploads a service photo (§36). The form holds the returned id until save
  /// attaches it — an abandoned form leaves an unattached file behind.
  ResultFuture<UploadedImage> uploadImage(String path) =>
      _files.upload(filePath: path, purpose: FilePurpose.serviceImage);

  /// Create (§47) or update (§48). Returns null on success, otherwise the
  /// message the form should show — the sheet stays open on failure.
  Future<String?> save(ServiceDraft draft) async {
    if (state.isSaving) return null;
    emit(state.copyWith(isSaving: true));

    final result = draft.isNew
        ? await _repo.createService(
            _businessId,
            draft,
            idempotencyKey: _createKey ??= newIdempotencyKey(),
          )
        : await _repo.updateService(_businessId, draft);

    final failure = result.match<Failure?>((f) => f, (_) => null);
    emit(state.copyWith(isSaving: false));
    if (failure != null) {
      // A coded rejection is stored against the key, so replaying it replays
      // the rejection; only a transport failure may reuse the key.
      if (draft.isNew && failure.code != null) _createKey = null;
      return failure.message;
    }

    _createKey = null;
    await _fetch(silent: true);
    return null;
  }

  /// §49. Deactivates rather than deletes — booking snapshots keep the history.
  Future<void> deactivate(String serviceId) async {
    if (state.actingServiceId != null) return;
    emit(state.copyWith(actingServiceId: serviceId, message: null));

    final result = await _repo.deactivateService(_businessId, serviceId);
    final failure = result.match<Failure?>((f) => f, (_) => null);
    emit(
      state.copyWith(actingServiceId: null, message: failure?.message),
    );
    if (failure == null) await _fetch(silent: true);
  }

  Future<void> _fetch({required bool silent}) async {
    if (silent) emit(state.copyWith(isRefreshing: true));

    final servicesResult = await _repo.listServices(_businessId);
    if (isClosed) return;
    final services = servicesResult.match<List<ManagedService>?>(
      (_) => null,
      (value) => value,
    );

    if (services == null) {
      emit(
        silent
            // A background refresh failure keeps the last-known list on screen.
            ? state.copyWith(isRefreshing: false)
            : state.copyWith(
                status: ServiceListStatus.failure,
                isRefreshing: false,
                message: servicesResult.match((f) => f.message, (_) => null),
              ),
      );
      return;
    }

    // The eligibility picker is decoration — a failed staff read must not take
    // the catalog down with it, so the previous options stay.
    final staffResult = await _repo.listStaffOptions(_businessId);
    if (isClosed) return;

    emit(
      state.copyWith(
        status: services.isEmpty
            ? ServiceListStatus.empty
            : ServiceListStatus.success,
        services: services,
        staff: staffResult.match((_) => state.staff, (value) => value),
        isRefreshing: false,
        message: null,
      ),
    );
  }
}
