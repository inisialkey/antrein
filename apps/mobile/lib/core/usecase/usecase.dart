import 'package:antrein/core/utils/typedefs.dart';

abstract class UseCase<Output, Params> {
  const UseCase();

  ResultFuture<Output> call(Params params);
}

class NoParams {
  const NoParams();
}
