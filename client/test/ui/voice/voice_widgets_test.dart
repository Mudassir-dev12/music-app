import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/player/persistence.dart';
import 'package:melodia/player/player_state.dart';
import 'package:melodia/player/queue.dart';
import 'package:melodia/theme/app_theme.dart';
import 'package:melodia/ui/voice/mic_button.dart';
import 'package:melodia/ui/voice/mic_status_indicator.dart';
import 'package:melodia/ui/voice/ride_mode_screen.dart';
import 'package:melodia/ui/voice/voice_help_sheet.dart';
import 'package:melodia/ui/voice/voice_settings_section.dart';
import 'package:melodia/voice/voice_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../fakes/fake_speech_ports.dart';

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeRecognizer = FakeSpeechRecognizer();
    fakeSynthesizer = FakeSpeechSynthesizer();
    fakeAudioRoute = FakeAudioRoute();
  });

  Widget wrapWithTheme(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        speechRecognizerProvider.overrideWithValue(fakeRecognizer),
        speechSynthesizerProvider.overrideWithValue(fakeSynthesizer),
        audioRouteProvider.overrideWithValue(fakeAudioRoute),
        persistenceServiceProvider.overrideWithValue(FakePersistenceService()),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('MicStatusIndicator shows label and indicator dot', (tester) async {
    await tester.pumpWidget(wrapWithTheme(
      const MicStatusIndicator(showLabel: true),
    ));

    expect(find.byType(MicStatusIndicator), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('MicButton renders microphone icon and tooltip', (tester) async {
    await tester.pumpWidget(wrapWithTheme(
      const MicButton(),
    ));

    expect(find.byType(MicButton), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);

    await tester.tap(find.byType(MicButton));
    await tester.pumpAndSettle();

    expect(fakeRecognizer.listening, isTrue);
  });

  testWidgets('VoiceHelpSheet renders categories and commands', (tester) async {
    await tester.pumpWidget(wrapWithTheme(
      const VoiceHelpSheet(),
    ));

    expect(find.text('Voice Commands'), findsOneWidget);
    expect(find.text('Playback'), findsOneWidget);
    expect(find.text('Volume & Seek'), findsOneWidget);
  });

  testWidgets('VoiceSettingsSection renders switches and language options', (tester) async {
    await tester.pumpWidget(wrapWithTheme(
      const SingleChildScrollView(child: VoiceSettingsSection()),
    ));

    expect(find.text('VOICE CONTROL & RIDE MODE'), findsOneWidget);
    expect(find.text('Ride Mode Auto-start'), findsOneWidget);
    expect(find.text('Spoken Confirmations'), findsOneWidget);
    expect(find.text('Voice Language'), findsOneWidget);
    expect(find.text('Smart Understanding (AI Fallback)'), findsOneWidget);
  });

  testWidgets('RideModeScreen renders high-contrast controls and auto-starts listening', (tester) async {
    await tester.pumpWidget(wrapWithTheme(
      const RideModeScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(RideModeScreen), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
    expect(find.text('Hands-free Listening'), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.text('Stop Listening'), findsOneWidget);
    expect(fakeRecognizer.listening, isTrue);
  });
}
