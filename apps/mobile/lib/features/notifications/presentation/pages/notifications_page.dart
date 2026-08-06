import 'dart:async';

import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/notifications/domain/entities/app_notification.dart';
import 'package:antrein/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The notification inbox (contract §92–§95). The cubit is provided above the
/// customer shell so the tab badge stays live from every tab — this page only
/// consumes it.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.watch<NotificationsCubit>();
    final state = cubit.state;

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.tabNotifications),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => unawaited(cubit.markAllRead()),
              child: Text(l10n.notificationsMarkAllRead),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(unreadOnly: state.unreadOnly),
          Expanded(
            child: switch (state.status) {
              NotificationsStatus.initial ||
              NotificationsStatus.loading => const AppLoading(),
              NotificationsStatus.failure => AppEmpty(
                message: state.message ?? l10n.notificationsLoadFailed,
                icon: Icons.error_outline,
              ),
              NotificationsStatus.empty => RefreshIndicator(
                onRefresh: cubit.refresh,
                // A scrollable is required for pull-to-refresh to fire.
                child: ListView(
                  children: [
                    SizedBox(height: 120.r),
                    AppEmpty(
                      message: state.unreadOnly
                          ? l10n.notificationsEmptyUnread
                          : l10n.notificationsEmpty,
                      icon: Icons.notifications_none,
                    ),
                  ],
                ),
              ),
              NotificationsStatus.success => RefreshIndicator(
                onRefresh: cubit.refresh,
                child: ListView.separated(
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= state.items.length) {
                      // Reaching the footer is the load-more trigger; building
                      // it means the last row is on screen. Deferred to after
                      // the frame — `loadMore` emits, and emitting into a build
                      // that is watching this cubit trips the framework.
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => unawaited(cubit.loadMore()),
                      );
                      return const Padding(
                        padding: EdgeInsets.all(Dimens.space16),
                        child: AppLoading(),
                      );
                    }
                    return _NotificationTile(item: state.items[index]);
                  },
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// ponytail: read state only. The backend also filters by `type`, but the two
/// live types are both queue events — add the filter when a third one lands.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.unreadOnly});

  final bool unreadOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<NotificationsCubit>();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Dimens.space16.r,
        vertical: Dimens.space8.r,
      ),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(l10n.notificationsFilterAll),
            selected: !unreadOnly,
            onSelected: (_) =>
                unawaited(cubit.setUnreadOnly(unreadOnly: false)),
          ),
          const Gap.horizontal(Dimens.space8),
          ChoiceChip(
            label: Text(l10n.notificationsFilterUnread),
            selected: unreadOnly,
            onSelected: (_) => unawaited(cubit.setUnreadOnly(unreadOnly: true)),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final cubit = context.read<NotificationsCubit>();

    return ListTile(
      leading: Icon(
        item.isRead
            ? Icons.notifications_none
            : Icons.notifications_active_outlined,
        color: item.isRead
            ? context.colorScheme.outline
            : context.colorScheme.primary,
      ),
      title: Text(
        item.title,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.body, style: context.textTheme.bodyMedium),
          const Gap(Dimens.space4),
          Text(
            DateFormat(
              'd MMM yyyy · HH:mm',
              locale,
            ).format(item.createdAt.toLocal()),
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () {
        unawaited(cubit.markRead(item));
        if (item.resourceType == 'booking' && item.resourceId != null) {
          unawaited(
            context.pushNamed(
              Routes.bookingDetail.name,
              pathParameters: {'bookingId': item.resourceId!},
            ),
          );
        }
      },
    );
  }
}
