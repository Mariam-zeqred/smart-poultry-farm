import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_poultry_farm/core/providers/firebase_providers.dart';
import 'package:smart_poultry_farm/core/widgets/notification_badge.dart';

void main() {
  Widget buildSubject({
    required AsyncValue<int> totalCount,
    required AsyncValue<int> criticalCount,
  }) {
    return ProviderScope(
      overrides: [
        activeAlertsCountProvider.overrideWith((_) => Stream.value(
              totalCount.when(
                data: (v) => v,
                loading: () => 0,
                error: (_, __) => 0,
              ),
            )),
        criticalAlertsCountProvider.overrideWith((_) => Stream.value(
              criticalCount.when(
                data: (v) => v,
                loading: () => 0,
                error: (_, __) => 0,
              ),
            )),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: AppBar(actions: const [NotificationBadgeIcon()]),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
  }

  group('NotificationBadgeIcon', () {
    testWidgets('shows no badge when there are zero active alerts',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        totalCount: const AsyncData(0),
        criticalCount: const AsyncData(0),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationBadgeIcon), findsOneWidget);
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('shows orange badge when there are warnings but no criticals',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        totalCount: const AsyncData(3),
        criticalCount: const AsyncData(0),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsOneWidget);

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.backgroundColor, equals(Colors.orange));
    });

    testWidgets('shows red badge when there are critical alerts',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        totalCount: const AsyncData(2),
        criticalCount: const AsyncData(1),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsOneWidget);

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.backgroundColor, equals(Colors.red));
    });

    testWidgets('badge label shows count capped at 99', (tester) async {
      await tester.pumpWidget(buildSubject(
        totalCount: const AsyncData(150),
        criticalCount: const AsyncData(0),
      ));
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('badge label shows exact count when under 100', (tester) async {
      await tester.pumpWidget(buildSubject(
        totalCount: const AsyncData(5),
        criticalCount: const AsyncData(0),
      ));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows loading state gracefully without crashing',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAlertsCountProvider
                .overrideWith((_) => const Stream.empty()),
            criticalAlertsCountProvider
                .overrideWith((_) => const Stream.empty()),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: AppBar(actions: const [NotificationBadgeIcon()]),
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.pump();

      // No crash, icon still renders
      expect(find.byType(NotificationBadgeIcon), findsOneWidget);
    });
  });
}
