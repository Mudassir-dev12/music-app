import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/core/connectivity/connectivity_controller.dart';

void main() {
  group('ConnectivityController', () {
    test('initial status is online', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(connectivityProvider);
      expect(state.status, equals(ConnectivityStatus.online));
      expect(state.isOnline, isTrue);
    });

    test('reportFailure transitions to reconnecting initially', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(connectivityProvider.notifier);
      notifier.reportFailure(error: Exception('500 Internal Server Error'));

      final state = container.read(connectivityProvider);
      expect(state.status, equals(ConnectivityStatus.reconnecting));
      expect(state.isOnline, isFalse);
    });

    test('reportFailure transitions to noInternet on offline socket error', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(connectivityProvider.notifier);
      notifier.reportFailure(error: Exception('SocketException: Network is unreachable'));

      final state = container.read(connectivityProvider);
      expect(state.status, equals(ConnectivityStatus.noInternet));
      expect(state.isOnline, isFalse);
    });

    test('reportFailure transitions to serverDown after 20 seconds of failure', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(connectivityProvider.notifier);
      // Set failure start time in the past
      notifier.setFailureStartTimeForTesting(DateTime.now().subtract(const Duration(seconds: 25)));
      notifier.reportFailure(error: Exception('Connection refused'));

      final state = container.read(connectivityProvider);
      expect(state.status, equals(ConnectivityStatus.serverDown));
      expect(state.isOnline, isFalse);
    });
  });
}

