import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The customer Home tab. A minimal welcome for M3 — the discovery feature
/// (business browsing/search) replaces this body in F2.
class CustomerHomePage extends StatelessWidget {
  const CustomerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.tabHome)),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final name = state is AuthAuthenticated ? state.user.name : '';
          return Center(
            child: Padding(
              padding: EdgeInsets.all(Dimens.space24.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.content_cut,
                    size: Dimens.iconXl.r,
                    color: context.colorScheme.primary,
                  ),
                  const Gap(Dimens.space16),
                  Text(
                    l10n.homeWelcome(name),
                    style: context.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(Dimens.space8),
                  Text(
                    l10n.homeDiscoverySoon,
                    style: context.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
