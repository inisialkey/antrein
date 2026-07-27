import 'package:antrein/app.dart';
import 'package:antrein/bootstrap.dart';

// Run: flutter run --flavor dev -t lib/main_dev.dart \
//   --dart-define-from-file=config/flavors/dev.json
// (Native --flavor wiring is deferred; the dart-define-from-file alone works.)
void main() => bootstrap(() => const App());
