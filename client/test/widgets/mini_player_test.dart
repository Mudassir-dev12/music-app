import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/player/player_controller.dart';
import 'package:melodia/player/player_state.dart';
import 'package:melodia/player/queue.dart';
import 'package:melodia/theme/app_theme.dart';
import 'package:melodia/ui/shell/mini_player.dart';

void main() {
  testWidgets('MiniPlayer is hidden (SizedBox.shrink) when queue is empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith(
            () => _FakePlayerController(PlayerStateData.initial()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            bottomNavigationBar: MiniPlayer(),
          ),
        ),
      ),
    );

    expect(find.text('Test Song'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('MiniPlayer shows title and play button when track is in queue',
      (WidgetTester tester) async {
    const track = Track(
      videoId: 'test_vid_123',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      artists: [Artist(name: 'Queen')],
      isExplicit: false,
    );

    final stateWithTrack = PlayerStateData(
      status: PlayerStatus.paused,
      queue: const QueueState(
        queue: [track],
        currentIndex: 0,
        playNextQueue: [],
        history: [],
        shuffle: false,
        repeat: RepeatMode.off,
        originalOrder: [track],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerControllerProvider.overrideWith(
            () => _FakePlayerController(stateWithTrack),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            bottomNavigationBar: MiniPlayer(),
          ),
        ),
      ),
    );

    expect(find.text('Bohemian Rhapsody'), findsOneWidget);
    expect(find.text('Queen'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);
  });
}

class _FakePlayerController extends PlayerController {
  _FakePlayerController(this._initial);
  final PlayerStateData _initial;

  @override
  PlayerStateData build() => _initial;
}
