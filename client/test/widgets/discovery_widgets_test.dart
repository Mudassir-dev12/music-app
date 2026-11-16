import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/discovery_api.dart';
import 'package:melodia/api/discovery_models.dart';
import 'package:melodia/theme/app_theme.dart';
import 'package:melodia/ui/widgets/busy_banner.dart';
import 'package:melodia/ui/widgets/media_item_card.dart';
import 'package:melodia/ui/widgets/top_result_card.dart';
import 'package:mocktail/mocktail.dart';

class MockDiscoveryApi extends Mock implements DiscoveryApi {}

void main() {
  Widget buildApp(Widget child, [List<Override> overrides = const []]) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Discovery Widgets', () {
    testWidgets('MediaItemCard renders title and subtitle', (tester) async {
      const item = MediaItem(
        id: 'item_1',
        type: MediaItemType.album,
        title: 'A Rush of Blood to the Head',
        subtitle: 'Coldplay',
      );

      await tester.pumpWidget(buildApp(const MediaItemCard(item: item)));
      await tester.pumpAndSettle();

      expect(find.text('A Rush of Blood to the Head'), findsOneWidget);
      expect(find.text('Coldplay'), findsOneWidget);
    });

    testWidgets('TopResultCard renders artist badge and title', (tester) async {
      const item = MediaItem(
        id: 'art_1',
        type: MediaItemType.artist,
        title: 'Coldplay',
        subtitle: 'Artist',
      );

      await tester.pumpWidget(buildApp(const TopResultCard(item: item)));
      await tester.pumpAndSettle();

      expect(find.text('ARTIST'), findsOneWidget);
      expect(find.text('Coldplay'), findsOneWidget);
    });

    testWidgets('BusyBanner displays retry countdown', (tester) async {
      await tester.pumpWidget(buildApp(const BusyBanner(retryAfterSeconds: 8)));
      await tester.pump();

      expect(
        find.text('The music service is busy right now. Retrying in 8s...'),
        findsOneWidget,
      );
    });
  });
}
