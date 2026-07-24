import 'package:flutter/material.dart';

/// Custom semantic colors that Material's [ColorScheme] does not express
/// (success / warning / info). Each is carried per brightness, so dark mode and
/// animated theme transitions resolve automatically — never a manual `xxxDark`
/// pair, never force-unwrapped. Read via `context.appColors`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.success,
    required this.warning,
    required this.info,
  });

  final Color success;
  final Color warning;
  final Color info;

  // Aligned to the brand system: available/confirm green, amber warning, sky
  // info (ui-ux-pro-max Booking & Appointment palette).
  static const AppPalette light = AppPalette(
    success: Color(0xFF059669), // emerald-600
    warning: Color(0xFFF59E0B), // amber-500
    info: Color(0xFF0EA5E9), // sky-500
  );

  static const AppPalette dark = AppPalette(
    success: Color(0xFF34D399), // emerald-400
    warning: Color(0xFFFBBF24), // amber-400
    info: Color(0xFF38BDF8), // sky-400
  );

  @override
  AppPalette copyWith({Color? success, Color? warning, Color? info}) =>
      AppPalette(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        info: info ?? this.info,
      );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
