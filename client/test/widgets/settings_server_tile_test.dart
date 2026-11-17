import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    final container = ProviderContainer();
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

