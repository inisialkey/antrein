import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/features/business_queue/business_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The business shell home. MVP surfaces the staff queue board for the user's
/// business (contract §82); an account with no membership sees the placeholder.
class BusinessHomePage extends StatelessWidget {
  const BusinessHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final membership = authState is AuthAuthenticated
        ? authState.user.primaryMembership
        : null;

    if (membership == null) {
      final l10n = context.l10n;
      return AppScaffold(
        appBar: AppBar(
          title: Text(l10n.businessAreaTitle),
          actions: [
            IconButton(
              tooltip: l10n.signOut,
              onPressed: () => context.read<AuthCubit>().signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: AppEmpty(
          message: l10n.businessAreaSoon,
          icon: Icons.storefront_outlined,
        ),
      );
    }

    return StaffQueuePage(
      businessId: membership.businessId,
      membershipOutletIds: membership.outletIds,
      canManage: membership.can('queue.manage'),
      canReorder: membership.can('queue.reorder'),
      canViewReports: membership.can('reports.read'),
      businessName: membership.businessName,
    );
  }
}
