import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_poultry_farm/core/widgets/app_startup.dart';

void main() {
  group('AppStartup', () {
    testWidgets('shows loading indicator while initializing', (tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appInitProvider.overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(
            home: AppStartup(child: Text('App Ready')),
          ),
        ),
      );

      // Single frame — loading state must render without hanging
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('App Ready'), findsNothing);
    });

    testWidgets('shows child widget when initialization succeeds',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appInitProvider.overrideWith((ref) async {}),
          ],
          child: const MaterialApp(
            home: AppStartup(child: Text('App Ready')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('App Ready'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows retry UI when initialization fails offline',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appInitProvider.overrideWith(
              (ref) async => throw Exception('Network unavailable'),
            ),
          ],
          child: const MaterialApp(
            home: AppStartup(child: Text('App Ready')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('App Ready'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AppInitError), findsOneWidget);
    });

    testWidgets('retry button re-triggers initialization', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appInitProvider.overrideWith((ref) async {
              callCount++;
              if (callCount == 1) throw Exception('Network unavailable');
            }),
          ],
          child: const MaterialApp(
            home: AppStartup(child: Text('App Ready')),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AppInitError), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('App Ready'), findsOneWidget);
      expect(callCount, equals(2));
    });

    testWidgets('shows offline-specific message when network fails',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appInitProvider.overrideWith(
              (ref) async => throw Exception('SocketException: No address'),
            ),
          ],
          child: const MaterialApp(
            home: AppStartup(child: Text('App Ready')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('offline'), findsOneWidget);
    });
  });
}
