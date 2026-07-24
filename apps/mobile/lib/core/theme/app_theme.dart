import 'package:antrein/core/theme/app_colors.dart';
import 'package:antrein/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Context-free M3 themes. Color comes from a seeded [ColorScheme] (text colored
/// by `onSurface`, dark mode resolved automatically — no per-style `color:`, no
/// `xxxDark`); custom semantics ride along as the [AppPalette] extension.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _base(Brightness.light, AppPalette.light);

  static ThemeData dark() => _base(Brightness.dark, AppPalette.dark);

  static ThemeData _base(Brightness brightness, AppPalette palette) =>
      ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.seed,
          brightness: brightness,
        ),
        // Themed once here so AppTextField stays a thin wrapper.
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        extensions: [palette],
      );
}
