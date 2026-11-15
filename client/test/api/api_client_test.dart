import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/errors.dart';

void main() {
  group('ApiError hierarchy and parsing', () {
    test('RateLimitError carries retryAfterSeconds', () {
      const error = RateLimitError(retryAfterSeconds: 45);
      expect(error.retryAfterSeconds, equals(45));
      expect(error.message, contains('Too many requests'));
    });

    test('ValidationError carries field map', () {
      const error = ValidationError(
        fields: {'email': 'Invalid email address'},
      );
      expect(error.fields['email'], equals('Invalid email address'));
      expect(error.message, contains('Validation failed'));
    });

    test('UnauthorizedError is an ApiError', () {
      const error = UnauthorizedError();
      expect(error, isA<ApiError>());
      expect(error.message, contains('Unauthorized'));
    });

    test('ServerError carries custom message and status code', () {
      const error = ServerError(statusCode: 503, message: 'Service unavailable');
      expect(error.statusCode, equals(503));
      expect(error.message, equals('Service unavailable'));
    });
  });
}
