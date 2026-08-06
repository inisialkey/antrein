import 'dart:async';

import 'package:antrein/core/extensions/extensions.dart';
import 'package:antrein/core/ui/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// ponytail: an injectable [launchUrl] rather than a launcher class — the whole
/// point of the seam is that a widget test can hand back `false`.
typedef UrlOpener = Future<bool> Function(Uri url, {LaunchMode mode});

/// Sends the customer to the provider-hosted checkout page of a pending online
/// payment (§72). The page is opened in the system browser, not an in-app
/// WebView: 3-D Secure steps and bank apps redirect out of the app and back.
///
/// The app never learns the outcome here — a client callback is not proof of
/// payment. The booking flips on the webhook, and the card's status refresh is
/// how the customer pulls that in.
///
/// ponytail: the sandbox gateway host does not resolve, so the browser opens on
/// an error page until a real provider (Midtrans Snap) is wired. The launch
/// itself is what was missing, and that part is provider-agnostic.
class CheckoutButton extends StatelessWidget {
  const CheckoutButton({required this.url, this.open = launchUrl, super.key});

  final String url;
  final UrlOpener open;

  @override
  Widget build(BuildContext context) => AppButton(
    label: context.l10n.payNowAction,
    onPressed: () => unawaited(_open(context)),
  );

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedMessage = context.l10n.checkoutOpenFailed;
    final uri = Uri.tryParse(url);

    var launched = false;
    if (uri != null) {
      try {
        launched = await open(uri, mode: LaunchMode.externalApplication);
      } on PlatformException catch (_) {
        launched = false;
      }
    }
    if (launched) return;

    // Nothing on the device takes an https URL, or the plugin refused it. Hand
    // the link over so the payment stays reachable from somewhere else.
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(SnackBar(content: Text(failedMessage)));
  }
}
