import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodia/core/connectivity/connectivity_controller.dart';
import 'package:melodia/theme/app_theme.dart';
import 'package:melodia/ui/widgets/connection_status_banner.dart';

void main() {
  testWidgets('ConnectionStatusBanner is hidden when online',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: ConnectionStatusBanner(),
          ),
        ),
      ),
    );

    expect(find.text('Reconnecting...'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('ConnectionStatusBanner displays message and Retry button when reconnecting',
      (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(connectivityProvider.notifier)
        .setStatusForTesting(ConnectivityStatus.reconnecting);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: ConnectionStatusBanner(),
          ),
        ),
      ),
    );

    expect(find.text("Can't reach the music server. Trying again..."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('ConnectionStatusBanner displays no internet message when offline',
      (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(connectivityProvider.notifier)
        .setStatusForTesting(ConnectivityStatus.noInternet);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: ConnectionStatusBanner(),
          ),
        ),
      ),
    );

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}

