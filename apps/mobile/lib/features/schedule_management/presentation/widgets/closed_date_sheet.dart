import 'dart:async';

import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/schedule_management/presentation/cubit/schedule_management_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Adds a one-off outlet closure (§57). There is no delete endpoint in v1, so
/// the sheet confirms before it commits.
void openClosedDateSheet(BuildContext context) {
  final cubit = context.read<ScheduleManagementCubit>();
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _ClosedDateSheet()),
    ),
  );
}

class _ClosedDateSheet extends StatefulWidget {
  const _ClosedDateSheet();

  @override
  State<_ClosedDateSheet> createState() => _ClosedDateSheetState();
}

class _ClosedDateSheetState extends State<_ClosedDateSheet> {
  final _reason = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSaving = context.select<ScheduleManagementCubit, bool>(
      (cubit) => cubit.state.isSavingClosedDate,
    );
    final date = _date;

    return Padding(
      padding: EdgeInsets.only(
        left: Dimens.space16.r,
        right: Dimens.space16.r,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Dimens.space16.r,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.closedDateAdd, style: context.textTheme.titleMedium),
          const Gap(Dimens.space16),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(date == null ? l10n.closedDatePick : _iso(date)),
            onPressed: () => unawaited(_pickDate()),
          ),
          const Gap(Dimens.space12),
          AppTextField(
            controller: _reason,
            label: l10n.closedDateReason,
            textInputAction: TextInputAction.done,
          ),
          const Gap(Dimens.space16),
          AppButton(
            label: l10n.commonSave,
            loading: isSaving,
            onPressed: date == null ? null : () => unawaited(_submit()),
          ),
          const Gap(Dimens.space8),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      // The backend rejects a past date with SCHEDULE_DATE_IN_PAST.
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final date = _date;
    if (date == null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final reason = _reason.text.trim();

    final error = await context.read<ScheduleManagementCubit>().addClosedDate(
      _iso(date),
      reason.isEmpty ? null : reason,
    );
    if (!mounted) return;
    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
  }

  static String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
