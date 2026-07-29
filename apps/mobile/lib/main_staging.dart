import 'package:antrein/app.dart';
import 'package:antrein/bootstrap.dart';

// Run: make mobile-staging — see main_dev.dart on why there is no `--flavor`.
//   flutter run -t lib/main_staging.dart --dart-define-from-file=config/flavors/staging.json
void main() => bootstrap(() => const App());
