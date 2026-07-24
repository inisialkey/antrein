import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Generic placeholder for shell tabs whose feature lands in a later milestone
/// (Bookings, Notifications, …). Keeps the shell navigable end-to-end in M3.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: Text(title)),
    body: AppEmpty(
      message: context.l10n.comingSoon,
      icon: Icons.hourglass_empty,
    ),
  );
}
