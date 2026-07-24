import 'package:antrein/core/config/app_config.dart';
import 'package:antrein/core/config/flavor.dart';

/// Registry of bundled in-app image asset paths, selected per flavor from the
/// single `FLAVOR` source ([AppConfig.flavor]) via an exhaustive switch.
///
/// Launcher icons are native (flutter_launcher_icons), not Flutter assets — they
/// do not belong here. Light vs dark is resolved by the caller (see `AppLogo`),
/// never baked into the flavor.
abstract final class Images {
  static const String _dir = 'assets/images';

  static Flavor get _flavor => AppConfig.fromEnvironment().flavor;

  static String get logo => switch (_flavor) {
    Flavor.production => '$_dir/logo.png',
    Flavor.staging => '$_dir/logo_stg.png',
    Flavor.dev => '$_dir/logo_dev.png',
  };

  static String get logoDark => switch (_flavor) {
    Flavor.production => '$_dir/logo_dark.png',
    Flavor.staging => '$_dir/logo_stg_dark.png',
    Flavor.dev => '$_dir/logo_dev_dark.png',
  };
}
