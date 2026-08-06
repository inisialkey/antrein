import 'package:equatable/equatable.dart';

/// Payment options a business can offer (api-contract §44).
const String payAtLocationOption = 'pay_at_location';
const String fullPaymentOption = 'full_payment';
const String depositOption = 'deposit';

/// Booking rules the owner controls (api-contract §44 `bookingPolicy`).
class BookingPolicy extends Equatable {
  const BookingPolicy({
    this.minimumLeadMinutes = 60,
    this.maximumAdvanceDays = 30,
    this.automaticConfirmation = true,
  });

  final int minimumLeadMinutes;
  final int maximumAdvanceDays;
  final bool automaticConfirmation;

  BookingPolicy copyWith({
    int? minimumLeadMinutes,
    int? maximumAdvanceDays,
    bool? automaticConfirmation,
  }) => BookingPolicy(
    minimumLeadMinutes: minimumLeadMinutes ?? this.minimumLeadMinutes,
    maximumAdvanceDays: maximumAdvanceDays ?? this.maximumAdvanceDays,
    automaticConfirmation: automaticConfirmation ?? this.automaticConfirmation,
  );

  @override
  List<Object?> get props => [
    minimumLeadMinutes,
    maximumAdvanceDays,
    automaticConfirmation,
  ];
}

/// Refund ladder applied when a customer cancels (ADR 0018 defaults).
class CancellationPolicy extends Equatable {
  const CancellationPolicy({
    this.fullRefundBeforeMinutes = 360,
    this.partialRefundBeforeMinutes = 120,
    this.partialRefundPercentage = 50,
    this.noShowRefundPercentage = 0,
  });

  final int fullRefundBeforeMinutes;
  final int partialRefundBeforeMinutes;
  final int partialRefundPercentage;
  final int noShowRefundPercentage;

  CancellationPolicy copyWith({
    int? fullRefundBeforeMinutes,
    int? partialRefundBeforeMinutes,
    int? partialRefundPercentage,
    int? noShowRefundPercentage,
  }) => CancellationPolicy(
    fullRefundBeforeMinutes:
        fullRefundBeforeMinutes ?? this.fullRefundBeforeMinutes,
    partialRefundBeforeMinutes:
        partialRefundBeforeMinutes ?? this.partialRefundBeforeMinutes,
    partialRefundPercentage:
        partialRefundPercentage ?? this.partialRefundPercentage,
    noShowRefundPercentage:
        noShowRefundPercentage ?? this.noShowRefundPercentage,
  );

  @override
  List<Object?> get props => [
    fullRefundBeforeMinutes,
    partialRefundBeforeMinutes,
    partialRefundPercentage,
    noShowRefundPercentage,
  ];
}

/// The business as its owner manages it (api-contract §44).
class ManagedBusiness extends Equatable {
  const ManagedBusiness({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.logoFileId,
    this.supportedPaymentOptions = const [],
    this.bookingPolicy = const BookingPolicy(),
    this.cancellationPolicy = const CancellationPolicy(),
    this.defaultDepositValue = 0,
  });

  final String id;
  final String name;
  final String? description;

  /// Absolute §37.1 URL of the current logo, or null when none is attached.
  final String? logoUrl;

  /// A freshly uploaded file (§36) to attach on the next save; null leaves the
  /// logo untouched.
  final String? logoFileId;
  final List<String> supportedPaymentOptions;
  final BookingPolicy bookingPolicy;
  final CancellationPolicy cancellationPolicy;

  /// Fixed default deposit in IDR (ADR 0022 — percentage is out of MVP).
  final int defaultDepositValue;

  bool allows(String option) => supportedPaymentOptions.contains(option);

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    logoUrl,
    logoFileId,
    supportedPaymentOptions,
    bookingPolicy,
    cancellationPolicy,
    defaultDepositValue,
  ];
}

/// The outlet fields §46 can change.
class ManagedOutlet extends Equatable {
  const ManagedOutlet({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.address,
  });

  final String id;
  final String name;
  final String? phoneNumber;
  final String? address;

  @override
  List<Object?> get props => [id, name, phoneNumber, address];
}
