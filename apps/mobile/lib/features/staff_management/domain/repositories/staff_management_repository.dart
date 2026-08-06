import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/staff_management/domain/entities/managed_staff.dart';

abstract class StaffManagementRepository {
  /// Roster including deactivated members (§41 with `activeOnly=false`).
  ResultFuture<List<ManagedStaff>> listStaff(String businessId);

  /// §50 — returns the invitation id; the member appears in the roster only
  /// after they accept (§51). Emailed by the backend, best-effort.
  ResultFuture<String> inviteStaff(
    String businessId,
    StaffDraft draft, {
    required String idempotencyKey,
  });

  /// §52.
  ResultVoid updateStaff(String businessId, StaffDraft draft);

  /// §53 — rejected with `STAFF_HAS_ACTIVE_BOOKINGS` while future bookings
  /// exist (ADR 0036).
  ResultVoid deactivateStaff(String businessId, String staffId);

  /// §51 — accepted by the invited user with their own token.
  ResultVoid acceptInvitation(
    String invitationId, {
    required String idempotencyKey,
  });
}
