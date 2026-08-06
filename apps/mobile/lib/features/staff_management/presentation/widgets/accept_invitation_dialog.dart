import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:antrein/features/staff_management/presentation/cubit/accept_invitation_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Asks for the invitation id from the invite email and accepts it (§51).
/// Resolves to true once the account has joined, so the caller can re-read
/// `/me` — the new membership is what unlocks the business shell.
Future<bool> showAcceptInvitationDialog(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => getIt<AcceptInvitationCubit>(),
      child: const _AcceptInvitationDialog(),
    ),
  );
  return accepted ?? false;
}

class _AcceptInvitationDialog extends StatefulWidget {
  const _AcceptInvitationDialog();

  @override
  State<_AcceptInvitationDialog> createState() =>
      _AcceptInvitationDialogState();
}

class _AcceptInvitationDialogState extends State<_AcceptInvitationDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final submitting = context.watch<AcceptInvitationCubit>().state;
    return AlertDialog(
      title: Text(l10n.invitationJoinTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.invitationJoinBody),
          const Gap(Dimens.space12),
          AppTextField(
            controller: _controller,
            label: l10n.invitationCodeLabel,
            enabled: !submitting,
            errorText: _error,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: submitting ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: submitting ? null : _submit,
          child: Text(l10n.invitationJoinAction),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = context.l10n.fieldRequired);
      return;
    }
    final navigator = Navigator.of(context);
    final error = await context.read<AcceptInvitationCubit>().accept(code);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    navigator.pop(true);
  }
}
