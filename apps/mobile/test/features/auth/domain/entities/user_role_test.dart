import 'package:antrein/features/auth/domain/entities/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRole.fromWire', () {
    test('maps the known wire values', () {
      expect(UserRole.fromWire('customer'), UserRole.customer);
      expect(UserRole.fromWire('business_owner'), UserRole.businessOwner);
      expect(UserRole.fromWire('staff'), UserRole.staff);
    });

    test('returns null for unknown or empty values', () {
      expect(UserRole.fromWire('admin'), isNull);
      expect(UserRole.fromWire(''), isNull);
    });
  });
}
