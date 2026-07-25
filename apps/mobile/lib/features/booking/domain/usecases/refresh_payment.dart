import 'package:antrein/core/usecase/usecase.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:antrein/features/booking/domain/repositories/booking_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

@injectable
class RefreshPayment
    extends UseCase<PaymentRefreshResult, RefreshPaymentParams> {
  const RefreshPayment(this._repository);

  final BookingRepository _repository;

  @override
  ResultFuture<PaymentRefreshResult> call(RefreshPaymentParams params) =>
      _repository.refreshPayment(params.paymentId);
}

class RefreshPaymentParams extends Equatable {
  const RefreshPaymentParams({required this.paymentId});

  final String paymentId;

  @override
  List<Object?> get props => [paymentId];
}
