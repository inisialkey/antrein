import 'package:antrein/core/router/routes.dart';

/// The unauthenticated routes — reachable while logged out, and off-limits once
/// logged in. Not `const` because enum `.path` is a getter.
final Set<String> authRoutePaths = {
  Routes.login.path,
  Routes.register.path,
  Routes.forgotPassword.path,
  Routes.resetPassword.path,
};

/// Pure auth/role-gating decision for the router redirect. The single source of
/// truth is the auth state (never storage): [isLoggedIn] and, for shell
/// selection, [hasBusinessAccess].
///
/// - Logged out → forced onto an auth route (login unless already on one).
/// - Logged in on an auth route → sent to the role home.
/// - Logged in on the business shell without business access → customer home.
/// - Otherwise no redirect (a business/multi-role user may still use the
///   customer shell — the roles collapse into two shells, not three).
String? resolveAuthRedirect({
  required bool isLoggedIn,
  required bool hasBusinessAccess,
  required String location,
}) {
  final onAuthRoute = authRoutePaths.contains(location);

  if (!isLoggedIn) {
    return onAuthRoute ? null : Routes.login.path;
  }

  if (onAuthRoute) {
    return hasBusinessAccess
        ? Routes.businessHome.path
        : Routes.customerHome.path;
  }

  if (location == Routes.businessHome.path && !hasBusinessAccess) {
    return Routes.customerHome.path;
  }

  return null;
}
