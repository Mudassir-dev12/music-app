import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/player/persistence.dart';
import 'package:melodia/player/player_controller.dart';
import 'package:melodia/player/player_state.dart';
import 'package:melodia/player/queue.dart';
import 'package:melodia/voice/speech_port.dart';
import 'package:melodia/voice/voice_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../fakes/fake_speech_ports.dart';

class FakePersistenceService extends PersistenceService {
  @override
  void saveStateDebounced(PlayerStateData state) {}
  @override
  Future<void> saveState(PlayerStateData state) async {}
  @override
  Future<({QueueState queue, Duration position, double volume})?> restoreState() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSpeechRecognizer fakeRecognizer;
  late FakeSpeechSynthesizer fakeSynthesizer;
  late FakeAudioRoute fakeAudioRoute;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeRecognizer = FakeSpeechRecognizer();
    fakeSynthesizer = FakeSpeechSynthesizer();
    fakeAudioRoute = FakeAudioRoute();

    container = ProviderContainer(
      overrides: [
        speechRecognizerProvider.overrideWithValue(fakeRecognizer),
        speechSynthesizerProvider.overrideWithValue(fakeSynthesizer),
        audioRouteProvider.overrideWithValue(fakeAudioRoute),
        persistenceServiceProvider.overrideWithValue(FakePersistenceService()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('starts listening and transitions state to listening', () async {
    final controller = container.read(voiceControllerProvider.notifier);
    await controller.startListening();

    final state = container.read(voiceControllerProvider);
    expect(state.status, equals(VoiceStatus.listening));
    expect(fakeRecognizer.listening, isTrue);
  });

  test('stops listening when StopListening command is spoken', () async {
    final controller = container.read(voiceControllerProvider.notifier);
    await controller.startListening();

    fakeRecognizer.simulateResult('stop listening');
    await pumpEventQueue();

    final state = container.read(voiceControllerProvider);
    expect(state.status, equals(VoiceStatus.idle));
    expect(fakeRecognizer.listening, isFalse);
    expect(fakeSynthesizer.spokenTexts, contains('Stopped listening.'));
  });

  test('ducks audio on phone speaker and unducks after speech', () async {
    fakeAudioRoute.setConnected(false); // phone speaker
    final player = container.read(playerControllerProvider.notifier);
    await player.setVolume(1.0);

    final controller = container.read(voiceControllerProvider.notifier);
    await controller.startListening();

    // Volume should be ducked to 30%
    final duckedVol = container.read(playerControllerProvider).volume;
    expect(duckedVol, closeTo(0.3, 0.05));

    await controller.stopListening();
    await pumpEventQueue();

    // Volume should be restored
    final restoredVol = container.read(playerControllerProvider).volume;
    expect(restoredVol, closeTo(1.0, 0.05));
  });

  test('keeps normal volume when earbuds are connected', () async {
    fakeAudioRoute.setConnected(true); // earbuds
    final player = container.read(playerControllerProvider.notifier);
    await player.setVolume(0.8);

    final controller = container.read(voiceControllerProvider.notifier);
    await controller.startListening();

    final currentVol = container.read(playerControllerProvider).volume;
    expect(currentVol, closeTo(0.8, 0.01));
  });

  test('handles spoken disambiguation selection (one/two)', () async {
    final controller = container.read(voiceControllerProvider.notifier);
    await controller.startListening();

    // Set disambiguation candidates directly
    const t1 = Track(
      videoId: 'v1',
      title: 'Song Alpha',
      artist: 'Artist A',
      artists: [],
      isExplicit: false,
    );
    const t2 = Track(
      videoId: 'v2',
      title: 'Song Beta',
      artist: 'Artist B',
      artists: [],
      isExplicit: false,
    );

    // Simulate disambiguation state
    container.read(voiceControllerProvider.notifier).state =
        container.read(voiceControllerProvider).copyWith(
              disambiguationCandidates: const [t1, t2],
            );

    // User chooses "one"
    fakeRecognizer.simulateResult('one');
    await pumpEventQueue();

    expect(fakeSynthesizer.spokenTexts, contains('Playing Song Alpha.'));
    final disambigAfter =
        container.read(voiceControllerProvider).disambiguationCandidates;
    expect(disambigAfter, isNull);
  });

  test('backoff stops continuous restarting after 5 consecutive errors', () async {
    final controller = container.read(voiceControllerProvider.notifier);
    await controller.startListening(continuous: true);

    for (int i = 0; i < 5; i++) {
      fakeRecognizer.simulateError(const VoiceError(
        kind: VoiceErrorKind.recognitionTimeout,
        message: 'Timeout error',
      ));
    }
    await pumpEventQueue();

    final state = container.read(voiceControllerProvider);
    expect(state.status, equals(VoiceStatus.error));
    expect(state.consecutiveFailures, equals(5));
    expect(state.errorMessage, contains('multiple errors'));
  });
}
