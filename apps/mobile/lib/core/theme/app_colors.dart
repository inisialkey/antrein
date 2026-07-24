import 'package:flutter/material.dart';

/// Raw brand **source** colors — the inputs the [ColorScheme] is seeded from.
/// Theme-derived colors are read via `context.colorScheme`; custom semantics
/// (success/warning/info) live in `AppPalette`. Keep this tiny.
abstract final class AppColors {
  static const Color seed = Color(0xFF2962FF);
}
