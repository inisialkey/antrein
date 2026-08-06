import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/utils/idempotency.dart';
import 'package:antrein/features/service_management/service_management.dart';
import 'package:antrein/features/staff_management/domain/entities/managed_staff.dart';
import 'package:antrein/features/staff_management/domain/repositories/staff_management_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'staff_management_state.dart';
part 'staff_management_cubit.freezed.dart';

/// The owner's staff roster (api-contract §41, §50, §52, §53).
///
/// Reads the service catalog through `service_management` for the eligibility
/// picker — one-way, so the two features never import each other in a cycle.
@injectable
class StaffManagementCubit extends Cubit<StaffManagementState> {
  StaffManagementCubit(this._repo, this._services)
    : super(const StaffManagementState());

  final StaffManagementRepository _repo;
  final ServiceManagementRepository _services;

  late String _businessId;
  late List<String> _outletIds;
  String? _inviteKey;

  Future<void> load(String businessId, {required String outletId}) async {
    _businessId = businessId;
    // MVP businesses have one outlet; the board that opened this page already
    // resolved it, so an invite assigns it without another lookup.
    _outletIds = [outletId];
    emit(state.copyWith(status: StaffListStatus.loading, message: null));
    await _fetch(silent: false);
  }

  Future<void> refresh() => _fetch(silent: true);

  /// Invite (§50) or update (§52). Returns null on success, otherwise the
  /// message the form should show.
  Future<String?> save(StaffDraft draft) async {
    if (state.isSaving) return null;
    emit(state.copyWith(isSaving: true));

    if (draft.isInvite) {
      final result = await _repo.inviteStaff(
        _businessId,
        StaffDraft(
          displayName: draft.displayName,
          role: draft.role,
          email: draft.email,
          outletIds: _outletIds,
          eligibleServiceIds: draft.eligibleServiceIds,
        ),
        idempotencyKey: _inviteKey ??= newIdempotencyKey(),
      );
      final failure = result.match<Failure?>((f) => f, (_) => null);
      emit(state.copyWith(isSaving: false));
      if (failure != null) {
        // A coded rejection is stored against the key; replaying it would
        // replay the rejection.
        if (failure.code != null) _inviteKey = null;
        return failure.message;
      }
      _inviteKey = null;
      // No roster row yet — the member appears once they accept (§51).
      emit(
        state.copyWith(
          invitationId: result.match((_) => null, (id) => id),
          invitedEmail: draft.email,
        ),
      );
      return null;
    }

    final result = await _repo.updateStaff(_businessId, draft);
    final failure = result.match<Failure?>((f) => f, (_) => null);
    emit(state.copyWith(isSaving: false));
    if (failure != null) return failure.message;
    await _fetch(silent: true);
    return null;
  }

  /// §53. The backend refuses while future bookings exist
  /// (`STAFF_HAS_ACTIVE_BOOKINGS`), and that message is what the owner sees.
  Future<void> deactivate(String staffId) async {
    if (state.actingStaffId != null) return;
    emit(state.copyWith(actingStaffId: staffId, message: null));

    final result = await _repo.deactivateStaff(_businessId, staffId);
    final failure = result.match<Failure?>((f) => f, (_) => null);
    emit(state.copyWith(actingStaffId: null, message: failure?.message));
    if (failure == null) await _fetch(silent: true);
  }

  /// Drops the invitation banner once the owner has seen (and copied) it.
  void clearInvitation() =>
      emit(state.copyWith(invitationId: null, invitedEmail: null));

  Future<void> _fetch({required bool silent}) async {
    if (silent) emit(state.copyWith(isRefreshing: true));

    final staffResult = await _repo.listStaff(_businessId);
    if (isClosed) return;
    final staff = staffResult.match<List<ManagedStaff>?>(
      (_) => null,
      (value) => value,
    );

    if (staff == null) {
      emit(
        silent
            // A background refresh failure keeps the last-known roster up.
            ? state.copyWith(isRefreshing: false)
            : state.copyWith(
                status: StaffListStatus.failure,
                isRefreshing: false,
                message: staffResult.match((f) => f.message, (_) => null),
              ),
      );
      return;
    }

    // The eligibility picker is decoration — a failed catalog read must not
    // take the roster down with it.
    final servicesResult = await _services.listServices(_businessId);
    if (isClosed) return;

    emit(
      state.copyWith(
        status: staff.isEmpty ? StaffListStatus.empty : StaffListStatus.success,
        staff: staff,
        services: servicesResult.match(
          (_) => state.services,
          (items) => items
              .map((s) => ServiceOption(id: s.id, name: s.name))
              .toList(growable: false),
        ),
        isRefreshing: false,
        message: null,
      ),
    );
  }
}
