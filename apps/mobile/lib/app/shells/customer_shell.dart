import 'dart:async';

import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/features/notifications/notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The customer navigation shell: a bottom `NavigationBar` over an
/// `IndexedStack` of the four customer tabs (flutter-brief §8). Each tab keeps
/// its own navigation state (go_router `StatefulShellRoute`).
class CustomerShell extends StatelessWidget {
  const CustomerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Index of the notifications tab — the one that carries the unread badge.
  static const int _notificationsTab = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unread = context.select<NotificationsCubit, String?>(
      (c) => c.state.unreadCount > 0 ? c.state.unreadLabel : null,
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // Opening the inbox refetches it — the cubit outlives the tab, so
          // without this the list is only as fresh as the last realtime event.
          if (index == _notificationsTab) {
            unawaited(context.read<NotificationsCubit>().refresh());
          }
          navigationShell.goBranch(
            index,
            // Re-tapping the active tab pops it back to its root.
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_outlined),
            selectedIcon: const Icon(Icons.event),
            label: l10n.tabBookings,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread != null,
              label: Text(unread ?? ''),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: l10n.tabNotifications,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.tabProfile,
          ),
        ],
      ),
    );
  }
}
