import 'dart:async';

import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/router/routes.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/features/staff_management/staff_management.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// The Profile tab: shows the signed-in user's `/me` details and the sign-out
/// action. Reads the app-scoped [AuthCubit].
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  /// Accepting an invitation adds a membership, and membership is what derives
  /// the business role — so `/me` has to be re-read before the shell opens up.
  Future<void> _joinBusiness(BuildContext context) async {
    final auth = context.read<AuthCubit>();
    final joined = await showAcceptInvitationDialog(context);
    if (!joined || !context.mounted) return;
    context.showSnackBar(context.l10n.invitationAccepted);
    await auth.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.tabProfile)),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return const AppLoading();
          }
          final user = state.user;
          return ListView(
            padding: EdgeInsets.all(Dimens.space16.r),
            children: [
              ListTile(
                leading: user.avatarUrl == null
                    ? const Icon(Icons.person_outline)
                    : ClipOval(
                        child: AppNetworkImage(
                          url: user.avatarUrl!,
                          width: Dimens.space32.r,
                          height: Dimens.space32.r,
                        ),
                      ),
                title: Text(user.name),
                subtitle: Text(user.email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    unawaited(context.pushNamed(Routes.profileEdit.name)),
              ),
              if (user.phoneNumber != null)
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(user.phoneNumber!),
                ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: Text(l10n.notificationPrefsTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => unawaited(
                  context.pushNamed(Routes.notificationPreferences.name),
                ),
              ),
              // The two ways into the business side (§43, §51). Both are hidden
              // once the account already belongs to a business — one business
              // per owner (ADR 0026), and staff already have their shell.
              if (user.primaryMembership == null) ...[
                const Gap(Dimens.space16),
                Text(
                  l10n.profileBusinessSection,
                  style: context.textTheme.titleSmall,
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(l10n.profileCreateBusiness),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      unawaited(context.pushNamed(Routes.createBusiness.name)),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(l10n.profileJoinBusiness),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_joinBusiness(context)),
                ),
              ],
              const Gap(Dimens.space24),
              AppButton(
                label: l10n.signOut,
                onPressed: () => context.read<AuthCubit>().signOut(),
              ),
            ],
          );
        },
      ),
    );
  }
}
