import 'package:antrein/core/error/failure_mapper.dart';
import 'package:antrein/core/network/api_endpoints.dart';
import 'package:antrein/core/network/envelope.dart';
import 'package:antrein/core/utils/typedefs.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

/// api-contract §36 purposes. The backend keys nothing off them today, but the
/// column is what a later cleanup job and the gallery limit will read.
abstract final class FilePurpose {
  static const String customerAvatar = 'customer_avatar';
  static const String businessLogo = 'business_logo';
  static const String staffAvatar = 'staff_avatar';
  static const String serviceImage = 'service_image';
}

/// An upload that has landed but is not attached to anything yet: the id goes
/// on the owning resource, the url is what the form shows straight away.
class UploadedImage extends Equatable {
  const UploadedImage({required this.id, required this.url});

  final String id;
  final String url;

  @override
  List<Object?> get props => [id, url];
}

/// Shared image upload (§36). Lives in core because four unrelated features
/// (profile, business settings, services, staff) upload through the same
/// endpoint — a per-feature copy would be the same twenty lines four times.
@lazySingleton
class FileUploadRepository {
  const FileUploadRepository(this._dio);

  final Dio _dio;

  ResultFuture<UploadedImage> upload({
    required String filePath,
    required String purpose,
  }) async {
    try {
      final data = await sendEnvelope(
        () async => _dio.post<dynamic>(
          ApiEndpoints.files,
          data: FormData.fromMap({
            'purpose': purpose,
            'file': await MultipartFile.fromFile(filePath),
          }),
        ),
      );
      return Right(
        UploadedImage(
          id: data['id'] as String,
          url: (data['url'] as String?) ?? '',
        ),
      );
    } on Exception catch (error) {
      return Left(mapExceptionToFailure(error, 'file.upload'));
    }
  }

  /// Discards an upload the user backed out of (§37). Best-effort: an orphan
  /// costs disk, and there is nothing useful to tell the user about it.
  Future<void> discard(String fileId) async {
    try {
      await _dio.delete<dynamic>(ApiEndpoints.file(fileId));
    } on Exception {
      // Intentionally silent — see above.
    }
  }
}
