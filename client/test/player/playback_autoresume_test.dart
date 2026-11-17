import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:melodia/player/player_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Playback auto-resume tracking', () {
    test('simulateNetworkFailure records failure position and state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      expect(controller.wasPlayingBeforeNetworkFailure, isFalse);

      controller.simulateNetworkFailureForTesting(const Duration(seconds: 45));
      expect(controller.wasPlayingBeforeNetworkFailure, isTrue);

      // Explicit pause clears network failure flag and resets attempt counter
      controller.pause();
      expect(controller.wasPlayingBeforeNetworkFailure, isFalse);
      expect(controller.autoResumeAttempts, equals(0));
    });
  });
}

