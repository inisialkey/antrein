import 'package:antrein/core/theme/app_colors.dart';
import 'package:antrein/core/theme/app_palette.dart';
import 'package:antrein/core/ui/dimens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Context-free Material 3 theme in the **Soft-UI Evolution** style
/// (ui-ux-pro-max): a seeded [ColorScheme] with the AntreIn brand roles locked
/// in ("calendar blue + available green"), Figtree (display/headline) + Noto
/// Sans (body) typography, softly-rounded filled inputs and buttons, and low
/// bordered surfaces. Colors always resolve through the scheme (no per-style
/// `color:`, no `xxxDark`); custom semantics ride the [AppPalette] extension.
///
/// Raw `Dimens` values are used directly here (not `.r`) — a `ThemeData` is
/// built once, context-free, so screenutil scaling cannot apply.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _base(Brightness.light, AppPalette.light);

  static ThemeData dark() => _base(Brightness.dark, AppPalette.dark);

  static ThemeData _base(Brightness brightness, AppPalette palette) {
    final isLight = brightness == Brightness.light;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.seed,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          tertiary: AppColors.accent,
          onTertiary: Colors.white,
          surface: isLight ? AppColors.lightSurface : AppColors.darkSurface,
          onSurface: isLight
              ? AppColors.lightForeground
              : AppColors.darkForeground,
          onSurfaceVariant: isLight
              ? AppColors.lightMutedForeground
              : AppColors.darkMutedForeground,
          outlineVariant: isLight
              ? AppColors.lightBorder
              : AppColors.darkBorder,
          error: AppColors.destructive,
          onError: Colors.white,
        );

    final text = _textTheme(scheme);
    final radiusMd = BorderRadius.circular(Dimens.radiusMd);
    final radiusLg = BorderRadius.circular(Dimens.radiusLg);
    final fill = isLight ? AppColors.lightMuted : AppColors.darkMuted;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight
          ? AppColors.lightBackground
          : AppColors.darkBackground,
      textTheme: text,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: isLight
            ? AppColors.lightBackground
            : AppColors.darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        foregroundColor: scheme.onSurface,
      ),
      // Softly-rounded filled fields — themed once so AppTextField stays thin.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Dimens.space16,
          vertical: Dimens.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Dimens.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(Dimens.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: radiusLg,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight
            ? AppColors.lightSurface
            : AppColors.darkSurface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 3,
        labelTextStyle: WidgetStateProperty.all(text.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
    );
  }

  /// Figtree for the large display/headline/title tiers, Noto Sans for body and
  /// labels (broad Indonesian/Latin coverage). Colors follow `onSurface`.
  static TextTheme _textTheme(ColorScheme scheme) {
    final body = GoogleFonts.notoSansTextTheme();
    final display = GoogleFonts.figtreeTextTheme();
    return body
        .copyWith(
          displayLarge: display.displayLarge,
          displayMedium: display.displayMedium,
          displaySmall: display.displaySmall,
          headlineLarge: display.headlineLarge,
          headlineMedium: display.headlineMedium,
          headlineSmall: display.headlineSmall,
          titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
