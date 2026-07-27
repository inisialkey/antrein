import 'package:antrein/core/network/api_error_codes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('errorCodeOf', () {
    test('extracts the nested error.code', () {
      expect(
        errorCodeOf({
          'success': false,
          'error': {'code': 'AUTH_INVALID_CREDENTIALS', 'message': 'x'},
        }),
        'AUTH_INVALID_CREDENTIALS',
      );
    });

    test('null when there is no error object or the body is not a map', () {
      expect(
        errorCodeOf({'success': true, 'data': <String, dynamic>{}}),
        isNull,
      );
      expect(errorCodeOf('nonsense'), isNull);
      expect(errorCodeOf(null), isNull);
    });
  });

  group('errorMessageOf', () {
    test('extracts the nested error.message', () {
      expect(
        errorMessageOf({
          'error': {'code': 'X', 'message': 'boom'},
        }),
        'boom',
      );
    });

    test('uses the fallback when absent', () {
      expect(errorMessageOf(null), 'Request failed.');
      expect(
        errorMessageOf({
          'error': {'code': 'X'},
        }, fallback: 'fb'),
        'fb',
      );
    });
  });

  group('refreshable', () {
    test('is exactly the access-token codes', () {
      expect(
        ApiErrorCodes.refreshable,
        contains(ApiErrorCodes.authAccessTokenExpired),
      );
      expect(
        ApiErrorCodes.refreshable,
        contains(ApiErrorCodes.authAccessTokenInvalid),
      );
      // Refresh-token failures must NOT trigger another refresh attempt.
      expect(
        ApiErrorCodes.refreshable.contains(
          ApiErrorCodes.authRefreshTokenInvalid,
        ),
        isFalse,
      );
    });
  });
}
