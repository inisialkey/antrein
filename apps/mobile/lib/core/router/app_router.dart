import 'package:antrein/app/shells/coming_soon_page.dart';
import 'package:antrein/app/shells/customer_home_page.dart';
import 'package:antrein/app/shells/customer_shell.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/auth_redirect.dart';
import 'package:antrein/core/router/go_router_refresh_stream.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:antrein/features/auth/presentation/pages/login_page.dart';
import 'package:antrein/features/auth/presentation/pages/register_page.dart';
import 'package:antrein/features/auth/presentation/pages/reset_password_page.dart';
import 'package:antrein/features/business_dashboard/presentation/pages/business_home_page.dart';
import 'package:antrein/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

/// App-scoped router. Holds the one app-lifetime [AuthCubit] (injected; the
/// router is a singleton, so this single instance is shared with the widget
/// tree via `BlocProvider.value` — the Cubit stays a factory registration).
/// Redirects re-evaluate whenever the auth state changes.
@lazySingleton
class AppRouter {
  AppRouter(this.authCubit);

  final AuthCubit authCubit;

  late final GoRouter router = GoRouter(
    initialLocation: Routes.customerHome.path,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: GoRouterRefreshStream([authCubit.stream]),
    redirect: (context, state) {
      final authState = authCubit.state;
      final user = authState is AuthAuthenticated ? authState.user : null;
      return resolveAuthRedirect(
        isLoggedIn: user != null,
        hasBusinessAccess: user?.hasBusinessAccess ?? false,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: Routes.login.path,
        name: Routes.login.name,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.register.path,
        name: Routes.register.name,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: Routes.forgotPassword.path,
        name: Routes.forgotPassword.name,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.resetPassword.path,
        name: Routes.resetPassword.name,
        builder: (context, state) =>
            ResetPasswordPage(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: Routes.businessHome.path,
        name: Routes.businessHome.name,
        builder: (context, state) => const BusinessHomePage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            CustomerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.customerHome.path,
                name: Routes.customerHome.name,
                builder: (context, state) => const CustomerHomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.customerBookings.path,
                name: Routes.customerBookings.name,
                builder: (context, state) =>
                    ComingSoonPage(title: context.l10n.tabBookings),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.customerNotifications.path,
                name: Routes.customerNotifications.name,
                builder: (context, state) =>
                    ComingSoonPage(title: context.l10n.tabNotifications),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.customerProfile.path,
                name: Routes.customerProfile.name,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
