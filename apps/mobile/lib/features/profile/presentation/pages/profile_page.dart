import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The Profile tab: shows the signed-in user's `/me` details and the sign-out
/// action. Reads the app-scoped [AuthCubit].
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
                leading: const Icon(Icons.person_outline),
                title: Text(user.name),
                subtitle: Text(user.email),
              ),
              if (user.phoneNumber != null)
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(user.phoneNumber!),
                ),
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
