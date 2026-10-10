import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/models/alert_model.dart';
import '../../../core/models/vision_models.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/vision_alert_engine.dart';

/// Firebase I/O + reconciliation for the vision AI alarm system.
///
/// Direct port of vision_alerts_prototype/alerts-store.js, verified against
/// the live prototype (including the eval-lock fix for the duplicate-alert
/// race the browser test caught). Vision-origin alerts land in the exact
/// same `farm/alerts` collection the ESP32 firmware already writes to (see
/// firmware/firebase_client.cpp) — same schema, tagged with
/// deviceId "vision-ai" — so the existing Alert model, AlertRepository,
/// and NotificationBadgeIcon all pick them up for free.
///
/// `PoultrySystem/vision/analysis` is a single "latest snapshot" node the
/// separate desktop vision analyzer overwrites per session — it has no
/// history of its own. `farm/vision/history/{timestamp}` is this app's own
/// compact log, needed for the sustained/baseline rules and the trend
/// sparklines.
class VisionRepository {
  final DatabaseReference _root;
  VisionRepository(this._root);

  static const visionDeviceId = 'vision-ai';
  static const historyWindow = 8;

  DatabaseReference get _analysisRef => _root.child('PoultrySystem/vision/analysis');
  DatabaseReference get _historyRef => _root.child('farm/vision/history');
  DatabaseReference get _alertsRef => _root.child('farm/alerts');
  DatabaseReference get _thresholdsRef => _root.child('farm/config/visionThresholds');

  Stream<Map<dynamic, dynamic>?> watchAnalysis() {
    return _analysisRef.onValue.map((event) {
      final v = event.snapshot.value;
      return v is Map ? Map<dynamic, dynamic>.from(v) : null;
    });
  }

  Future<VisionThresholds> fetchThresholds() async {
    final snap = await _thresholdsRef.get();
    return VisionThresholds.fromMap(snap.value is Map ? Map<dynamic, dynamic>.from(snap.value as Map) : null);
  }

  Future<void> saveThresholds(VisionThresholds t) async {
    await _thresholdsRef.set(t.toMap());
  }

  Future<List<VisionRecord>> fetchHistory({int limit = historyWindow}) async {
    final snap = await _historyRef.get();
    if (!snap.exists || snap.value is! Map) return [];
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    final records = map.values
        .whereType<Map>()
        .map((m) => VisionRecord.fromMap(m))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (records.length <= limit) return records;
    return records.sublist(records.length - limit);
  }

  Future<List<Alert>> fetchAllAlerts() async {
    final snap = await _alertsRef.get();
    if (!snap.exists || snap.value is! Map) return [];
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    return map.entries
        .where((e) => e.value is Map)
        .map((e) => Alert.fromMap(e.key.toString(), e.value as Map))
        .toList();
  }

  // --- serialize every evaluation/reset call within this app instance ---
  //
  // Plain "read active alerts, then create/patch" isn't atomic. The
  // prototype's own browser test caught the real consequence: the
  // background poller and an in-flight simulateScenario() interleaved,
  // both saw "no alert of this type yet", and both created one —
  // duplicate rows. Chaining every call through one Future queue makes
  // them run one-at-a-time, which is enough for the single-evaluator
  // design this app assumes (see NotificationBadgeIcon / "in-app only"
  // notification scope — nothing here claims to be race-safe across two
  // separate app instances evaluating at once).
  Future<void> _evalLock = Future.value();

  Future<T> _withEvalLock<T>(Future<T> Function() fn) {
    final run = _evalLock.then((_) => fn());
    _evalLock = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<VisionEvalResult?> processLatestSnapshot({VisionThresholds? thresholdsOverride}) {
    return _withEvalLock(() => _processLatestSnapshotLocked(thresholdsOverride));
  }

  Future<VisionEvalResult?> _processLatestSnapshotLocked(VisionThresholds? thresholdsOverride) async {
    final snap = await _analysisRef.get();
    if (!snap.exists || snap.value is! Map) return null;
    final analysis = Map<dynamic, dynamic>.from(snap.value as Map);
    final ts = (analysis['timestamp'] as num?)?.toInt() ?? 0;
    if (ts == 0) return null;

    final record = VisionRecord.fromAnalysis(analysis);
    final alreadyLogged = await _historyRef.child('$ts').get();
    if (!alreadyLogged.exists) {
      await _historyRef.child('$ts').set(record.toMap());
    }

    // `record` is always treated as "current" and placed last structurally
    // (not by sort-on-value) — the one deliberately out-of-order case is
    // the `stale` simulate scenario, which sets an old timestamp on purpose.
    final history = await fetchHistory();
    final priorOnly = history.where((r) => r.timestamp != record.timestamp).toList();
    final records = [...priorOnly, record];

    final thresholds = thresholdsOverride ?? await fetchThresholds();
    final conditions = evaluateVisionSnapshot(records, thresholds, DateTime.now());
    await _reconcileAlerts(conditions);

    return VisionEvalResult(analysis: analysis, record: record, records: records, conditions: conditions);
  }

  Future<void> _reconcileAlerts(List<VisionCondition> conditions) async {
    final all = await fetchAllAlerts();
    final activeByType = <String, Alert>{};
    for (final a in all) {
      if (a.type.startsWith('vision_') && !a.isResolved) {
        activeByType[a.type] = a;
      }
    }

    final firingTypes = conditions.map((c) => c.type.wireValue).toSet();

    for (final c in conditions) {
      final existing = activeByType[c.type.wireValue];
      if (existing != null) {
        await _alertsRef.child(existing.id).update({
          'severity': c.severity,
          'value': c.value,
          'threshold': c.threshold,
          'params': c.params,
          'lastSeenAt': ServerValue.timestamp,
        });
      } else {
        await _alertsRef.push().set({
          'type': c.type.wireValue,
          'severity': c.severity,
          'message': _fallbackEnglishMessage(c),
          'value': c.value,
          'threshold': c.threshold,
          'params': c.params,
          'createdAt': ServerValue.timestamp,
          'lastSeenAt': ServerValue.timestamp,
          'deviceId': visionDeviceId,
        });
      }
    }

    for (final entry in activeByType.entries) {
      if (!firingTypes.contains(entry.key)) {
        await _alertsRef.child(entry.value.id).update({'resolvedAt': ServerValue.timestamp});
      }
    }
  }

  /// English fallback stored in `message` — matches what the JS prototype
  /// and ESP32 firmware write, so the raw Firebase record stays readable
  /// without the app, and old clients that don't know about `params` still
  /// show something sensible.
  String _fallbackEnglishMessage(VisionCondition c) {
    final p = c.params;
    num v(String key) => p[key] ?? 0;
    switch (c.type) {
      case VisionAlertType.visionStale:
        return 'No new AI analysis in ${v('minutes').round()} min — check the camera / desktop analyzer.';
      case VisionAlertType.visionUnhealthyRate:
        return 'Unhealthy detection rate at ${v('pct').toStringAsFixed(1)}% (${v('unhealthy').round()}/${v('total').round()} birds).';
      case VisionAlertType.visionActivityLow:
        return 'Activity level has been low for ${v('count').round()} consecutive sessions.';
      case VisionAlertType.visionBirdCountDrop:
        return 'Tracked bird count dropped to ${v('count').round()}, more than ${v('pct').toStringAsFixed(0)}% below the recent baseline (~${v('baseline').round()}).';
      case VisionAlertType.visionOvercrowding:
        return 'Activity-hotspot intensity per bird spiked to ${v('ratio').toStringAsFixed(2)} (~${v('multiplier').toStringAsFixed(1)}x recent baseline) near row ${v('row').round()}, col ${v('col').round()} — possible crowding/huddling.';
      case VisionAlertType.visionFeedingStalled:
        return 'Eat/drink activity has been under ${v('pct').toStringAsFixed(0)}% for ${v('count').round()} consecutive sessions — check feeder/waterer.';
      case VisionAlertType.visionCombinedHealthActivityRisk:
        return 'Unhealthy rate ${v('pct').toStringAsFixed(1)}% together with sustained low activity — inactivity may indicate illness rather than rest.';
      case VisionAlertType.visionCombinedMortalityRisk:
        return 'Bird count dropped to ${v('count').round()} (baseline ~${v('baseline').round()}) while unhealthy rate is ${v('pct').toStringAsFixed(1)}% — possible mortality event.';
    }
  }

  Future<void> acknowledgeAlert(String id) async {
    await _alertsRef.child(id).update({'acknowledgedAt': ServerValue.timestamp});
  }

  Future<void> resolveAlert(String id) async {
    await _alertsRef.child(id).update({'resolvedAt': ServerValue.timestamp});
  }

}

class VisionEvalResult {
  final Map<dynamic, dynamic> analysis;
  final VisionRecord record;
  final List<VisionRecord> records;
  final List<VisionCondition> conditions;

  const VisionEvalResult({
    required this.analysis,
    required this.record,
    required this.records,
    required this.conditions,
  });
}

final visionRepositoryProvider = Provider<VisionRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return VisionRepository(database);
});

/// Live "latest snapshot" node — raw map so the UI can read behavior/health
/// straight off it without an intermediate model, same as the JS prototype.
final visionAnalysisProvider = StreamProvider.autoDispose<Map<dynamic, dynamic>?>((ref) {
  ref.keepAlive();
  return ref.watch(visionRepositoryProvider).watchAnalysis();
});

final visionThresholdsProvider = FutureProvider.autoDispose<VisionThresholds>((ref) {
  return ref.watch(visionRepositoryProvider).fetchThresholds();
});

final visionHistoryProvider = FutureProvider.autoDispose<List<VisionRecord>>((ref) {
  // Re-fetches whenever a new analysis snapshot arrives, so the trend
  // sparklines stay in sync with the evaluator without their own polling.
  ref.watch(visionAnalysisProvider);
  return ref.watch(visionRepositoryProvider).fetchHistory();
});

/// All `farm/alerts` (sensor + vision, active + resolved) — the Vision
/// screen filters/sorts client-side so it can offer the "show resolved"
/// toggle without a second Firebase query shape.
final allAlertsProvider = StreamProvider.autoDispose<List<Alert>>((ref) {
  final repo = ref.watch(alertRepoProvider);
  return repo.watchAlerts(activeOnly: false, limit: 100);
});

/// Keeps listening to PoultrySystem/vision/analysis and reconciling
/// farm/alerts for as long as something is watching it. Wired into
/// App.build() in app.dart so it runs for the whole app lifetime, not just
/// while the Vision tab is on screen — matches the "alerts should surface
/// even from the Dashboard tab" requirement, same in-app-only scope as
/// NotificationBadgeIcon.
final visionEvaluatorProvider = Provider.autoDispose<void>((ref) {
  ref.keepAlive();
  final repo = ref.watch(visionRepositoryProvider);
  int? lastProcessedTimestamp;

  final sub = repo.watchAnalysis().listen((analysis) {
    final ts = (analysis?['timestamp'] as num?)?.toInt();
    if (ts == null || ts == 0 || ts == lastProcessedTimestamp) return;
    lastProcessedTimestamp = ts;
    repo.processLatestSnapshot().catchError((Object e) {
      debugPrint('Vision evaluator error: $e');
      return null;
    });
  });

  ref.onDispose(sub.cancel);
});
