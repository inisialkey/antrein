/// Raw design tokens (logical px on the 375×812 canvas — see `kDesignSize`).
///
/// Apply `.r` at the call site, **inside `build`** — never cache a screenutil
/// value in a `static`/`final` field: `static x = 16.r` is evaluated once on
/// first access and then frozen, so it ignores rotation, resize, split-screen,
/// and breaks in tests that run before `ScreenUtilInit`. Holding raw `const`
/// numbers keeps the tokens immutable and lets each call site pick its unit
/// (`.r` for sizes/spacing/radii, `.sp` for the rare inline font).
///
/// Font sizes intentionally live in the `TextTheme`, not here.
abstract final class Dimens {
  // Spacing scale (4/8dp rhythm)
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  // Icon / control sizes
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 40;
  static const double iconXl = 64;

  // Component sizes
  static const double thumbnail = 48;
  static const double logo = 96;
  static const double buttonHeight = 52;

  // Radii (soft-UI rounding)
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
}
