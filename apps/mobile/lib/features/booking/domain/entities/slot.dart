import 'package:equatable/equatable.dart';

/// One bookable time slot (api-contract §42). Informational only — the backend
/// revalidates on creation.
class Slot extends Equatable {
  const Slot({
    required this.startsAt,
    required this.endsAt,
    required this.available,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final bool available;

  @override
  List<Object?> get props => [startsAt, endsAt, available];
}
