import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The business shell — a stub until the business modules land in M4. Reachable
/// only by accounts with a business role (owner/staff), which the backend does
/// not grant yet, so in M3 this is unreachable-by-design but wired.
class BusinessHomePage extends StatelessWidget {
  const BusinessHomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
}
