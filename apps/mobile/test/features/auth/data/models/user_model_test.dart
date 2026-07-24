import 'package:antrein/features/auth/data/models/user_model.dart';
import 'package:antrein/features/auth/domain/entities/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    test('fromJson parses the /me shape and ignores extra fields', () {
      final model = UserModel.fromJson(const {
        'id': 'usr_1',
        'name': 'Oki',
        'email': 'oki@example.com',
        'phoneNumber': '+628123',
        'avatarUrl': null,
        'status': 'active',
        'roles': ['customer'],
        'businessMemberships': <dynamic>[],
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      expect(model.id, 'usr_1');
      expect(model.phoneNumber, '+628123');
      expect(model.roles, ['customer']);
    });

    test('defaults status and roles when absent', () {
      final model = UserModel.fromJson(const {
        'id': 'u',
        'name': 'n',
        'email': 'e@x.com',
      });
      expect(model.status, 'active');
      expect(model.roles, isEmpty);
    });

    test('toEntity maps role strings to UserRole and drops unknowns', () {
      const model = UserModel(
        id: 'usr_1',
        name: 'Oki',
        email: 'o@e.com',
        roles: ['customer', 'business_owner', 'nope'],
      );
      final user = model.toEntity();
      expect(user.roles, [UserRole.customer, UserRole.businessOwner]);
      expect(user.hasBusinessAccess, isTrue);
    });

    test('a customer-only account has no business access', () {
      const model = UserModel(
        id: 'u',
        name: 'n',
        email: 'e',
        roles: ['customer'],
      );
      expect(model.toEntity().hasBusinessAccess, isFalse);
    });
  });
}
