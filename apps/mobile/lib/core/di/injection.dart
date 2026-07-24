import 'package:antrein/core/di/injection.config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies(String environment) async {
  getIt.init(environment: environment);
}
