import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/api/models.dart';
import 'package:melodia/downloads/download_repository.dart';
import 'package:melodia/theme/app_theme.dart';
import 'package:melodia/ui/screens/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen displays Server Status tile and Test connection button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        downloadLimitsProvider.overrideWith((ref) => Future.value(
              const DownloadLimits(
                dailyDownloadMbLimit: 1000,
                dailyDownloadMbRemaining: 1000,
                remainingDownloadMb: 1000,
                maxDownloadTrackMb: 80,
                maxConcurrentDownloadsPerUser: 2,
                maxConcurrentDownloadsGlobal: 4,
              ),
            )),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const SettingsScreen(),
        ),
      ),
    );

    expect(find.text('Server Status'), findsOneWidget);
    expect(find.text('Test connection'), findsOneWidget);
    expect(find.textContaining('Online'), findsOneWidget);
  });
}

