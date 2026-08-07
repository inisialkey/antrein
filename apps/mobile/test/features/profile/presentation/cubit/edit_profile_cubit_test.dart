import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/files/file_upload_repository.dart';
import 'package:antrein/features/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockFileUploadRepository extends Mock implements FileUploadRepository {}

void main() {
  late MockProfileRepository repo;
  late MockFileUploadRepository files;

  setUpAll(() => registerFallbackValue(const ProfileDraft(name: 'x')));

  setUp(() {
    repo = MockProfileRepository();
    files = MockFileUploadRepository();
    when(
      () => repo.updateProfile(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  test('saves the draft and reports success', () async {
    final cubit = EditProfileCubit(repo, files);

    final error = await cubit.save(
      const ProfileDraft(name: 'Oki Key', phoneNumber: '+628111'),
    );

    expect(error, isNull);
    expect(cubit.state, isFalse);
    verify(
      () => repo.updateProfile(
        const ProfileDraft(name: 'Oki Key', phoneNumber: '+628111'),
      ),
    ).called(1);
    await cubit.close();
  });

  test('returns the backend message on a taken phone number', () async {
    when(() => repo.updateProfile(any())).thenAnswer(
      (_) async => const Left(
        ConflictFailure(
          'Nomor sudah dipakai.',
          code: 'USER_PHONE_ALREADY_USED',
        ),
      ),
    );

    final cubit = EditProfileCubit(repo, files);
    final error = await cubit.save(const ProfileDraft(name: 'Oki'));

    expect(error, 'Nomor sudah dipakai.');
    expect(cubit.state, isFalse);
    await cubit.close();
  });

  test('uploads an avatar with the customer_avatar purpose', () async {
    when(
      () => files.upload(
        filePath: any(named: 'filePath'),
        purpose: any(named: 'purpose'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        UploadedImage(id: 'fil_1', url: 'https://api.test/files/fil_1/content'),
      ),
    );

    final cubit = EditProfileCubit(repo, files);
    final result = await cubit.uploadAvatar('/tmp/a.jpg');

    expect(result.getRight().toNullable()?.id, 'fil_1');
    verify(
      () => files.upload(
        filePath: '/tmp/a.jpg',
        purpose: FilePurpose.customerAvatar,
      ),
    ).called(1);
    await cubit.close();
  });
}
