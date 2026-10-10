/// Riverpod providers for the Firebase Realtime Database root reference and the
/// alert streams consumed by the notification badge and the alerts list.
///
/// Everything reads the flat `farm/` tree — there is no per-user or
/// per-device namespace (single-farm design, see docs/ARCHITECTURE.md).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../features/devices/providers/alert_provider.dart';

final databaseProvider = Provider<DatabaseReference>((ref) => FirebaseDatabase.instance.ref());

// Alert repository provider (no auth needed — hardcoded device ID)
final alertRepoProvider = Provider<AlertRepository>((ref) {
  final database = FirebaseDatabase.instance;
  return AlertRepository(database);
});

// Active alerts stream
final activeAlertsProvider = StreamProvider((ref) {
  final repo = ref.watch(alertRepoProvider);
  return repo.watchAlerts(activeOnly: true, limit: 50);
});

// Active alerts count
final activeAlertsCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(alertRepoProvider);
  return repo.watchActiveAlertsCount();
});

// Critical alerts count
final criticalAlertsCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(alertRepoProvider);
  return repo.watchCriticalAlertsCount();
});