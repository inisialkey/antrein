import 'dart:async';

import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/profile/presentation/cubit/notification_preferences_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The four notification switches (api-contract §33). Each toggle writes on the
/// spot — see the cubit for why there is no Save button.
class NotificationPreferencesPage extends StatelessWidget {
  const NotificationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider(
      create: (_) {
        final cubit = getIt<NotificationPreferencesCubit>();
        unawaited(cubit.load());
        return cubit;
      },
      child: AppScaffold(
        appBar: AppBar(title: Text(l10n.notificationPrefsTitle)),
        body:
            BlocConsumer<
              NotificationPreferencesCubit,
              NotificationPreferencesState
            >(
              listenWhen: (previous, current) =>
                  previous.savedTick != current.savedTick ||
                  (current.status == PreferencesStatus.success &&
                      previous.message != current.message &&
                      current.message != null),
              listener: (context, state) => context.showSnackBar(
                state.message ?? l10n.notificationPrefsSaved,
              ),
              builder: (context, state) => switch (state.status) {
                PreferencesStatus.initial ||
                PreferencesStatus.loading => const AppLoading(),
                PreferencesStatus.failure => AppEmpty(
                  message: state.message ?? l10n.notificationPrefsLoadFailed,
                  icon: Icons.error_outline,
                ),
                PreferencesStatus.success => _Switches(state: state),
              },
            ),
      ),
    );
  }
}

class _Switches extends StatelessWidget {
  const _Switches({required this.state});

  final NotificationPreferencesState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<NotificationPreferencesCubit>();
    final prefs = state.preferences;

    return ListView(
      padding: EdgeInsets.all(Dimens.space16.r),
      children: [
        Text(
          l10n.notificationPrefsSubtitle,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(Dimens.space8),
        SwitchListTile(
          title: Text(l10n.notificationPrefBooking),
          value: prefs.bookingUpdates,
          onChanged: state.isSaving
              ? null
              : (value) => unawaited(
                  cubit.toggle(prefs.copyWith(bookingUpdates: value)),
                ),
        ),
        SwitchListTile(
          title: Text(l10n.notificationPrefPayment),
          value: prefs.paymentUpdates,
          onChanged: state.isSaving
              ? null
              : (value) => unawaited(
                  cubit.toggle(prefs.copyWith(paymentUpdates: value)),
                ),
        ),
        SwitchListTile(
          title: Text(l10n.notificationPrefQueue),
          value: prefs.queueUpdates,
          onChanged: state.isSaving
              ? null
              : (value) => unawaited(
                  cubit.toggle(prefs.copyWith(queueUpdates: value)),
                ),
        ),
        SwitchListTile(
          title: Text(l10n.notificationPrefMarketing),
          value: prefs.marketing,
          onChanged: state.isSaving
              ? null
              : (value) =>
                    unawaited(cubit.toggle(prefs.copyWith(marketing: value))),
        ),
      ],
    );
  }
}
