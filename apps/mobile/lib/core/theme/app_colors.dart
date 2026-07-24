import 'package:flutter/material.dart';

/// Brand source colors for AntreIn — the "calendar blue + available green"
/// Booking & Appointment palette (ui-ux-pro-max). The Material 3 [ColorScheme]
/// is seeded from [seed]; `AppTheme` then locks the exact brand roles and
/// neutrals below. Read theme colors via `context.colorScheme`; success /
/// warning / info live in `AppPalette`.
abstract final class AppColors {
  /// Primary — calendar / trust blue (sky-600). Also the seed.
  static const Color seed = Color(0xFF0284C7);
  static const Color primary = Color(0xFF0284C7);
  static const Color secondary = Color(0xFF0EA5E9); // sky-500
  /// Accent — available / confirm green (emerald-600).
  static const Color accent = Color(0xFF059669);
  static const Color destructive = Color(0xFFDC2626);

  // Light neutrals
  static const Color lightBackground = Color(0xFFF0F9FF); // sky-50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightForeground = Color(0xFF0F172A); // slate-900
  static const Color lightMuted = Color(0xFFEFF7FB);
  static const Color lightMutedForeground = Color(0xFF64748B); // slate-500
  static const Color lightBorder = Color(0xFFE0F0F8);

  // Dark neutrals (slate scale — kept accessible against the blue accents)
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111A2B);
  static const Color darkForeground = Color(0xFFE2E8F0); // slate-200
  static const Color darkMuted = Color(0xFF1B2740);
  static const Color darkMutedForeground = Color(0xFF94A3B8); // slate-400
  static const Color darkBorder = Color(0xFF25334D);
}
