import 'package:antrein/app.dart';
import 'package:antrein/bootstrap.dart';

// Run: make mobile-production — see main_dev.dart on why there is no `--flavor`.
//   flutter run -t lib/main_production.dart --dart-define-from-file=config/flavors/production.json
void main() => bootstrap(() => const App());
