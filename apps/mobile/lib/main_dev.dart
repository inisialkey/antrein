import 'package:antrein/app.dart';
import 'package:antrein/bootstrap.dart';

// Run: make mobile-dev — or, by hand:
//   flutter run -t lib/main_dev.dart --dart-define-from-file=config/flavors/dev.json
// No `--flavor`: flavors carry dart-defines only, and android/app/build.gradle.kts
// declares no productFlavors, so `--flavor dev` fails on `assembleDevDebug`.
void main() => bootstrap(() => const App());
