import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/api_client.dart';
import 'package:melodia/api/errors.dart';

void main() {
  group('ApiClient retry policy', () {
    test('succeeds immediately without retrying', () async {
      final client = ApiClient();
      int callCount = 0;

      final result = await client.retryIdempotentForTesting(() async {
        callCount++;
        return 'success';
      });

      expect(result, equals('success'));
      expect(callCount, equals(1));
    });

    test('retries on NetworkError and succeeds on second attempt', () async {
      final client = ApiClient();
      int callCount = 0;

      final result = await client.retryIdempotentForTesting(() async {
        callCount++;
        if (callCount == 1) {
          throw const NetworkError('Connection timeout');
        }
        return 'recovered';
      });

      expect(result, equals('recovered'));
      expect(callCount, equals(2));
    });

    test('retries up to 2 times (3 total) and then rethrows and notifies callback', () async {
      final client = ApiClient();
      int callCount = 0;
      Object? reportedError;
      client.onNetworkFailure = (err) {
        reportedError = err;
      };

      await expectLater(
        () => client.retryIdempotentForTesting(() async {
          callCount++;
          throw const ServerError(statusCode: 503, message: 'Unavailable');
        }),
        throwsA(isA<ServerError>()),
      );

      // 1 initial + 2 retries = 3 attempts
      expect(callCount, equals(3));
      expect(reportedError, isA<ServerError>());
    });

    test('does not retry non-transient errors like UnauthorizedError', () async {
      final client = ApiClient();
      int callCount = 0;

      await expectLater(
        () => client.retryIdempotentForTesting(() async {
          callCount++;
          throw const UnauthorizedError('Invalid token');
        }),
        throwsA(isA<UnauthorizedError>()),
      );

      expect(callCount, equals(1));
    });
  });
}

