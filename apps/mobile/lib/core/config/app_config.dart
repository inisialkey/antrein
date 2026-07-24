import 'package:antrein/core/config/flavor.dart';

/// Immutable runtime configuration, resolved once from compile-time
/// `--dart-define`s (see `config/flavors/<flavor>.json` + `main_<flavor>.dart`).
/// Non-secret only; secrets never ship in the binary.
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.appName,
  });

  factory AppConfig.fromEnvironment() {
    const flavorName = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    // Android emulator reaches the host's localhost via 10.0.2.2; the backend
    // serves under the /api/v1 prefix (see apps/api). iOS simulator would use
    // http://localhost:3000/api/v1 — override via the flavor json when needed.
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000/api/v1',
    );
    const appName = String.fromEnvironment(
      'APP_NAME',
      defaultValue: 'AntreIn Dev',
    );
    return AppConfig(
      flavor: _parse(flavorName),
      apiBaseUrl: apiBaseUrl,
      appName: appName,
    );
  }

  final Flavor flavor;
  final String apiBaseUrl;
  final String appName;

  static Flavor _parse(String value) => Flavor.values.firstWhere(
    (f) => f.name == value,
    orElse: () => Flavor.dev,
  );
}
