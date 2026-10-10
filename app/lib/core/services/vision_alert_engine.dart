/// Pure alarm-decision logic for the GallineX vision AI feed.
///
/// Direct port of vision_alerts_prototype/vision-alert-engine.js, verified
/// against the live prototype (all 9 scenarios + the mortality/unhealthy-
/// rate double-fire fix). No Firebase/Flutter imports here on purpose —
/// this is plain data in, plain data out, so it stays as easy to test and
/// reason about as the JS original.
///
/// Two rules are intentionally RELATIVE rather than fixed-threshold
/// (overcrowding, feeding-stalled): the real GallineX report's own two
/// sessions show hotspot intensity 51-63 and eat-drink share as low as
/// 2.7% during perfectly NORMAL sessions. A fixed absolute cutoff would
/// false-alarm on ordinary noise.
library;

import '../models/vision_models.dart';

double? _median(List<double> nums) {
  if (nums.isEmpty) return null;
  final sorted = [...nums]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

bool _lastNAllTrue(List<VisionRecord> records, int n, bool Function(VisionRecord) pred) {
  if (records.length < n) return false;
  return records.sublist(records.length - n).every(pred);
}

/// [records]: ascending by timestamp; LAST element is the snapshot being
/// evaluated. [now]: passed in (not read via DateTime.now() internally) so
/// this stays pure and easy to test.
List<VisionCondition> evaluateVisionSnapshot(
  List<VisionRecord> records,
  VisionThresholds t,
  DateTime now,
) {
  final current = records.last;
  final prior = records.sublist(0, records.length - 1);
  final out = <VisionCondition>[];

  // --- staleness: time-based, independent of everything else ---
  final ageMin = (now.millisecondsSinceEpoch - current.timestamp) / 60000;
  if (ageMin > t.staleMinutes) {
    out.add(VisionCondition(
      type: VisionAlertType.visionStale,
      severity: 'warning',
      params: {'minutes': ageMin.round()},
      value: ageMin.round(),
      threshold: t.staleMinutes,
    ));
    // Data this old shouldn't drive biological alarms — they may no longer hold.
    return out;
  }

  final unhealthyCritical = current.unhealthyPct >= t.unhealthyCriticalPct;
  final unhealthyWarn = current.unhealthyPct >= t.unhealthyWarnPct;

  final activityLowSustained = _lastNAllTrue(
    records, t.activityLowSustainedCount, (r) => r.activityLevel == 'low');

  final recentBirdCounts = (prior.length > 5 ? prior.sublist(prior.length - 5) : prior)
      .map((r) => r.birdCount.toDouble())
      .toList();
  final birdBaselineMedian = _median(recentBirdCounts);
  final dropFloor = birdBaselineMedian != null ? birdBaselineMedian * (1 - t.birdCountDropPct / 100) : null;
  final birdCountDropSustained = dropFloor != null &&
      _lastNAllTrue(records, t.birdCountSustainedCount, (r) => r.birdCount <= dropFloor);

  final feedingStalledSustained = _lastNAllTrue(
      records, t.feedingSustainedCount, (r) => r.eatDrinkPct < t.feedingStalledPct);

  final recentForRatio = prior.length > 5 ? prior.sublist(prior.length - 5) : prior;
  final priorRatios = recentForRatio
      .where((r) => r.birdCount > 0)
      .map((r) => r.hotspotIntensity / r.birdCount)
      .toList();
  final ratioBaseline = _median(priorRatios);
  final currentRatio = current.birdCount > 0 ? current.hotspotIntensity / current.birdCount : 0.0;
  final overcrowdingSpike = priorRatios.length >= 3 &&
      ratioBaseline != null &&
      ratioBaseline > 0 &&
      currentRatio >= ratioBaseline * t.hotspotSpikeRatio;

  // Fused conditions win over their standalone parts — one clear critical
  // alert beats two overlapping ones for the same underlying event. (This
  // mirrors a real bug the prototype's own browser test caught: mortality
  // risk originally still let a redundant standalone unhealthy-rate alert
  // through because only the health+activity combo suppressed it.)
  final combinedHealthActivity = unhealthyWarn && activityLowSustained;
  final combinedMortalityRisk = birdCountDropSustained && unhealthyWarn;
  final suppressIndividualHealthActivity = combinedHealthActivity || combinedMortalityRisk;

  if (combinedMortalityRisk) {
    out.add(VisionCondition(
      type: VisionAlertType.visionCombinedMortalityRisk,
      severity: 'critical',
      params: {
        'count': current.birdCount,
        // birdBaselineMedian is guaranteed non-null here: this branch only
        // runs when combinedMortalityRisk/birdCountDropSustained is true,
        // which requires dropFloor != null, which is only ever computed
        // from a non-null birdBaselineMedian — a guarantee the analyzer's
        // local flow typing can't see through the indirection.
        'baseline': birdBaselineMedian!.round(),
        'pct': current.unhealthyPct,
      },
      value: current.birdCount,
      threshold: dropFloor.round(),
    ));
  } else if (birdCountDropSustained) {
    out.add(VisionCondition(
      type: VisionAlertType.visionBirdCountDrop,
      severity: 'critical',
      params: {
        'count': current.birdCount,
        'pct': t.birdCountDropPct,
        // birdBaselineMedian is guaranteed non-null here: this branch only
        // runs when combinedMortalityRisk/birdCountDropSustained is true,
        // which requires dropFloor != null, which is only ever computed
        // from a non-null birdBaselineMedian — a guarantee the analyzer's
        // local flow typing can't see through the indirection.
        'baseline': birdBaselineMedian!.round(),
      },
      value: current.birdCount,
      threshold: dropFloor.round(),
    ));
  }

  if (combinedHealthActivity && !combinedMortalityRisk) {
    out.add(VisionCondition(
      type: VisionAlertType.visionCombinedHealthActivityRisk,
      severity: 'critical',
      params: {'pct': current.unhealthyPct},
      value: current.unhealthyPct,
      threshold: t.unhealthyWarnPct,
    ));
  } else if (!suppressIndividualHealthActivity) {
    if (unhealthyCritical || unhealthyWarn) {
      out.add(VisionCondition(
        type: VisionAlertType.visionUnhealthyRate,
        severity: unhealthyCritical ? 'critical' : 'warning',
        params: {
          'pct': current.unhealthyPct,
          'unhealthy': current.unhealthy,
          'total': current.healthy + current.unhealthy,
        },
        value: current.unhealthyPct,
        threshold: unhealthyCritical ? t.unhealthyCriticalPct : t.unhealthyWarnPct,
      ));
    }
    if (activityLowSustained) {
      out.add(VisionCondition(
        type: VisionAlertType.visionActivityLow,
        severity: 'warning',
        params: {'count': t.activityLowSustainedCount},
        value: 0,
        threshold: t.activityLowSustainedCount,
      ));
    }
  }

  if (overcrowdingSpike) {
    final multiplier = currentRatio / ratioBaseline;
    out.add(VisionCondition(
      type: VisionAlertType.visionOvercrowding,
      severity: 'warning',
      params: {
        'ratio': double.parse(currentRatio.toStringAsFixed(2)),
        'multiplier': double.parse(multiplier.toStringAsFixed(1)),
        'row': current.hotspotRow ?? 0,
        'col': current.hotspotCol ?? 0,
      },
      value: double.parse(currentRatio.toStringAsFixed(2)),
      threshold: double.parse((ratioBaseline * t.hotspotSpikeRatio).toStringAsFixed(2)),
    ));
  }

  if (feedingStalledSustained) {
    out.add(VisionCondition(
      type: VisionAlertType.visionFeedingStalled,
      severity: 'critical',
      params: {
        'pct': t.feedingStalledPct,
        'count': t.feedingSustainedCount,
      },
      value: current.eatDrinkPct,
      threshold: t.feedingStalledPct,
    ));
  }

  return out;
}

