import 'package:antrein/features/booking/presentation/widgets/checkout_button.dart';
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

const _url = 'https://sandbox.payments.antrein.local/checkout/sbx_pay_1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  String? copiedText() => platformCalls
      .where((c) => c.method == 'Clipboard.setData')
      .map((c) => (c.arguments as Map)['text'] as String?)
      .lastOrNull;

  Future<void> pump(WidgetTester tester, UrlOpener open) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CheckoutButton(url: _url, open: open),
      ),
    ),
  );

  testWidgets('opens the checkout page in an external browser', (tester) async {
    Uri? opened;
    LaunchMode? usedMode;
    await pump(tester, (url, {mode = LaunchMode.platformDefault}) {
      opened = url;
      usedMode = mode;
      return Future.value(true);
    });

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(opened, Uri.parse(_url));
    // A real browser session, not an in-app WebView: 3-D Secure and bank apps
    // redirect out of the app and back again.
    expect(usedMode, LaunchMode.externalApplication);
    expect(copiedText(), isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('hands over the link when no browser can take it', (
    tester,
  ) async {
    await pump(
      tester,
      (url, {mode = LaunchMode.platformDefault}) => Future.value(false),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(copiedText(), _url);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a platform failure falls back to the clipboard too', (
    tester,
  ) async {
    await pump(
      tester,
      (url, {mode = LaunchMode.platformDefault}) =>
          Future.error(PlatformException(code: 'ACTIVITY_NOT_FOUND')),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(copiedText(), _url);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
