import 'package:antrein/app.dart';
import 'package:antrein/bootstrap.dart';

// Run: flutter run --flavor staging -t lib/main_staging.dart \
//   --dart-define-from-file=config/flavors/staging.json
void main() => bootstrap(() => const App());
