import 'package:antrein/core/theme/app_palette.dart';
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// Ergonomic shortcuts for the most-repeated `BuildContext` lookups.
/// Pure accessors only — no business logic.
extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Custom semantic colors (success/warning/info). Falls back to the light set
  /// if a bare theme has no extension registered, so call sites never crash.
  AppPalette get appColors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  TextTheme get textTheme => Theme.of(this).textTheme;

  AppLocalizations get l10n => AppLocalizations.of(this);

  MediaQueryData get mediaQuery => MediaQuery.of(this);

  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  void showSnackBar(String message) => ScaffoldMessenger.of(
    this,
  ).showSnackBar(SnackBar(content: Text(message)));
}
