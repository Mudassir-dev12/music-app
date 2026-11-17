import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/core/connectivity/connectivity_controller.dart';
import 'package:melodia/downloads/offline_mode.dart';

void main() {
  group('OfflineModeNotifier', () {
    test('defaults to online when no preferences set', () {
      final notifier = OfflineModeNotifier(null);
      expect(notifier.state.isOffline, isFalse);
      expect(notifier.state.isManual, isFalse);
      expect(notifier.state.isAuto, isFalse);
      notifier.dispose();
    });

    test('manual offline toggle turns offline on and off', () {
      final notifier = OfflineModeNotifier(null);
      notifier.setManualOffline(true);
      expect(notifier.state.isOffline, isTrue);
      expect(notifier.state.isManual, isTrue);
      expect(notifier.state.isAuto, isFalse);

      notifier.setManualOffline(false);
      expect(notifier.state.isOffline, isFalse);
      expect(notifier.state.isManual, isFalse);
      notifier.dispose();
    });

    test('auto offline triggers after 15 seconds of no connectivity', () {
      fakeAsync((async) {
        final notifier = OfflineModeNotifier(null);
        notifier.onConnectivityStateChanged(const ConnectivityState(
          status: ConnectivityStatus.noInternet,
        ));

        // Before 15 seconds: still online
        async.elapse(const Duration(seconds: 14));
        expect(notifier.state.isOffline, isFalse);

        // At 15 seconds: enters auto offline
        async.elapse(const Duration(seconds: 1));
        expect(notifier.state.isOffline, isTrue);
        expect(notifier.state.isAuto, isTrue);
        expect(notifier.state.isManual, isFalse);

        // When connectivity restored: auto offline clears immediately
        notifier.onConnectivityStateChanged(const ConnectivityState(
          status: ConnectivityStatus.online,
        ));
        expect(notifier.state.isOffline, isFalse);
        expect(notifier.state.isAuto, isFalse);

        notifier.dispose();
      });
    });

    test('manual offline takes precedence over auto connectivity changes', () {
      fakeAsync((async) {
        final notifier = OfflineModeNotifier(null);
        notifier.setManualOffline(true);

        notifier.onConnectivityStateChanged(const ConnectivityState(
          status: ConnectivityStatus.online,
        ));
        expect(notifier.state.isOffline, isTrue);
        expect(notifier.state.isManual, isTrue);

        notifier.dispose();
      });
    });
  });
}
