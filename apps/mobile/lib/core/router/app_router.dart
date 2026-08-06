import 'dart:async';

import 'package:antrein/app/shells/customer_shell.dart';
import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/router/auth_redirect.dart';
import 'package:antrein/core/router/go_router_refresh_stream.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:antrein/features/auth/presentation/pages/login_page.dart';
import 'package:antrein/features/auth/presentation/pages/register_page.dart';
import 'package:antrein/features/auth/presentation/pages/reset_password_page.dart';
import 'package:antrein/features/booking/domain/entities/booking_draft.dart';
import 'package:antrein/features/booking/presentation/pages/booking_confirm_page.dart';
import 'package:antrein/features/booking/presentation/pages/booking_detail_page.dart';
import 'package:antrein/features/booking/presentation/pages/my_bookings_page.dart';
import 'package:antrein/features/booking/presentation/pages/slot_picker_page.dart';
import 'package:antrein/features/business_bookings/business_bookings.dart';
import 'package:antrein/features/business_dashboard/presentation/pages/business_home_page.dart';
import 'package:antrein/features/business_management/business_management.dart';
import 'package:antrein/features/customer_queue/customer_queue.dart';
import 'package:antrein/features/discovery/presentation/pages/business_detail_page.dart';
import 'package:antrein/features/discovery/presentation/pages/discovery_page.dart';
import 'package:antrein/features/notifications/notifications.dart';
import 'package:antrein/features/profile/presentation/pages/profile_page.dart';
import 'package:antrein/features/reports/reports.dart';
import 'package:antrein/features/schedule_management/schedule_management.dart';
import 'package:antrein/features/service_management/service_management.dart';
import 'package:antrein/features/staff_management/staff_management.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  /// Permission on the primary membership. Read from the auth state rather than
  /// the widget tree so a route builder never has to look it up itself; the
  /// backend re-checks every mutation regardless.
  bool _can(String permission) {
    final state = authCubit.state;
    final membership = state is AuthAuthenticated
        ? state.user.primaryMembership
        : null;
    return membership?.can(permission) ?? false;
  }

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
      GoRoute(
        path: Routes.businessBookings.path,
        name: Routes.businessBookings.name,
        builder: (context, state) => BusinessBookingsPage(
          businessId: state.pathParameters['businessId']!,
          outletId: state.pathParameters['outletId']!,
        ),
      ),
      GoRoute(
        path: Routes.businessReports.path,
        name: Routes.businessReports.name,
        builder: (context, state) => DailySummaryPage(
          businessId: state.pathParameters['businessId']!,
          outletId: state.pathParameters['outletId']!,
        ),
      ),
      // Management screens. Each takes its own permission from the membership
      // the business shell resolved, so a staff account reaches them read-only.
      GoRoute(
        path: Routes.businessServices.path,
        name: Routes.businessServices.name,
        builder: (context, state) => ServiceManagementPage(
          businessId: state.pathParameters['businessId']!,
          canManage: _can('service.manage'),
        ),
      ),
      GoRoute(
        path: Routes.businessStaff.path,
        name: Routes.businessStaff.name,
        builder: (context, state) => StaffManagementPage(
          businessId: state.pathParameters['businessId']!,
          outletId: state.pathParameters['outletId']!,
          canManage: _can('staff.manage'),
        ),
      ),
      GoRoute(
        path: Routes.businessSchedule.path,
        name: Routes.businessSchedule.name,
        builder: (context, state) => ScheduleManagementPage(
          businessId: state.pathParameters['businessId']!,
          outletId: state.pathParameters['outletId']!,
          canManageOutlet: _can('business.manage'),
          canManageStaff: _can('staff.manage'),
        ),
      ),
      GoRoute(
        path: Routes.businessSettings.path,
        name: Routes.businessSettings.name,
        builder: (context, state) => BusinessSettingsPage(
          businessId: state.pathParameters['businessId']!,
          outletId: state.pathParameters['outletId']!,
          canManage: _can('business.manage'),
        ),
      ),
      GoRoute(
        path: Routes.createBusiness.path,
        name: Routes.createBusiness.name,
        builder: (context, state) => const CreateBusinessPage(),
      ),
      // Booking flow — full-screen pages pushed over the customer shell.
      GoRoute(
        path: Routes.businessDetail.path,
        name: Routes.businessDetail.name,
        builder: (context, state) => BusinessDetailPage(
          businessId: state.pathParameters['businessId']!,
        ),
      ),
      GoRoute(
        path: Routes.bookingSlots.path,
        name: Routes.bookingSlots.name,
        builder: (context, state) =>
            SlotPickerPage(args: state.extra! as SlotPickerArgs),
      ),
      GoRoute(
        path: Routes.bookingConfirm.path,
        name: Routes.bookingConfirm.name,
        builder: (context, state) =>
            BookingConfirmPage(draft: state.extra! as BookingDraft),
      ),
      GoRoute(
        path: Routes.bookingDetail.path,
        name: Routes.bookingDetail.name,
        builder: (context, state) => BookingDetailPage(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
      GoRoute(
        path: Routes.customerQueue.path,
        name: Routes.customerQueue.name,
        builder: (context, state) => CustomerQueuePage(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        // The inbox cubit is provided above the shell, not inside the tab: the
        // bottom-bar badge needs the unread count while any other tab is open.
        // Shell-scoped, so it is disposed (and its state dropped) on logout.
        builder: (context, state, navigationShell) => BlocProvider(
          create: (_) {
            final cubit = getIt<NotificationsCubit>();
            unawaited(cubit.load());
            return cubit;
          },
          child: CustomerShell(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.customerHome.path,
                name: Routes.customerHome.name,
                builder: (context, state) => const DiscoveryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.customerBookings.path,
                name: Routes.customerBookings.name,
                builder: (context, state) => const MyBookingsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.customerNotifications.path,
                name: Routes.customerNotifications.name,
                builder: (context, state) => const NotificationsPage(),
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
