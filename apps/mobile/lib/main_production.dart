import 'package:antrein/app.dart';
import 'package:antrein/bootstrap.dart';

// Run: flutter run --flavor production -t lib/main_production.dart \
//   --dart-define-from-file=config/flavors/production.json
void main() => bootstrap(() => const App());
