import 'package:antrein/features/auth/domain/entities/user.dart';
import 'package:antrein/features/auth/domain/entities/user_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Wire model for the API user object (login/register `data.user` and `/me`).
/// Field names already match the camelCase contract, so no `@JsonKey` renames.
/// Extra `/me` fields (notificationPreferences, businessMemberships, timestamps)
/// are ignored until the features that need them land.
@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String name,
    required String email,
    String? phoneNumber,
    String? avatarUrl,
    @Default('active') String status,
    @Default(<String>[]) List<String> roles,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  User toEntity() => User(
    id: id,
    name: name,
    email: email,
    roles: roles
        .map(UserRole.fromWire)
        .whereType<UserRole>()
        .toList(growable: false),
    phoneNumber: phoneNumber,
    avatarUrl: avatarUrl,
    status: status,
  );
}
