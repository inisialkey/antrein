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

  static const AppPalette light = AppPalette(
    success: Color(0xFF2E7D32),
    warning: Color(0xFFED6C02),
    info: Color(0xFF0288D1),
  );

  static const AppPalette dark = AppPalette(
    success: Color(0xFF66BB6A),
    warning: Color(0xFFFFB74D),
    info: Color(0xFF4FC3F7),
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
