import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Integer IDR money value object (backend invariant: never floats).
class Money extends Equatable {
  const Money(this.amount, [this.currency = 'IDR']);

  factory Money.fromJson(Map<String, dynamic> json) => Money(
    (json['amount'] as num?)?.toInt() ?? 0,
    json['currency'] as String? ?? 'IDR',
  );

  final int amount;
  final String currency;

  static final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  /// `Rp50.000` — locale id-ID grouping, no decimals.
  String get formatted => _idr.format(amount);

  Map<String, dynamic> toJson() => {'amount': amount, 'currency': currency};

  @override
  List<Object?> get props => [amount, currency];
}
