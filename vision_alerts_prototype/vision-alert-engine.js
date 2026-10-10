/**
 * Pure alarm-decision logic for the GallineX vision AI feed.
 *
 * Deliberately has NO Firebase/DOM calls in here — this module takes data in,
 * returns decisions out. That's on purpose: this is the exact logic that
 * gets ported into the Flutter app in stage 4 (as a plain Dart function/
 * class), so keeping it side-effect-free means the port is a translation
 * exercise, not a redesign.
 *
 * Two rules are intentionally RELATIVE rather than fixed-threshold
 * (overcrowding, feeding-stalled): the report's own two real sessions show
 * hotspot intensity 51–63 and eat-drink share as low as 2.7% during
 * perfectly NORMAL sessions. A fixed absolute cutoff would false-alarm on
 * ordinary noise. These two are flagged as heuristics to retune once real
 * camera data accumulates.
 */

const DEFAULT_VISION_THRESHOLDS = {
  unhealthyWarnPct: 15,        // report's own sustained-alert line is 30% (critical)
  unhealthyCriticalPct: 30,
  activityLowSustainedCount: 2, // consecutive "low" sessions before alarming
  birdCountDropPct: 20,         // % below rolling baseline
  birdCountSustainedCount: 2,
  hotspotSpikeRatio: 1.8,       // heuristic: x times the recent per-bird baseline
  feedingStalledPct: 3,         // heuristic: eat-drink share floor
  feedingSustainedCount: 3,
  staleMinutes: 20,             // no new analyzer timestamp in this long = "offline"
};

const ALL_VISION_ALERT_TYPES = [
  'vision_stale',
  'vision_unhealthy_rate',
  'vision_activity_low',
  'vision_bird_count_drop',
  'vision_overcrowding',
  'vision_feeding_stalled',
  'vision_combined_health_activity_risk',
  'vision_combined_mortality_risk',
];

function median(nums) {
  if (!nums.length) return null;
  const s = [...nums].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

function lastNAllTrue(records, n, pred) {
  if (records.length < n) return false;
  return records.slice(-n).every(pred);
}

/**
 * @param {Array} records - ascending by timestamp; LAST element is the
 *   snapshot being evaluated. Shape: {timestamp, birdCount, unhealthy,
 *   healthy, unhealthyPct, activityLevel, eatDrinkPct, hotspotIntensity,
 *   hotspotRow, hotspotCol}
 * @param {Object} thresholds - overrides for DEFAULT_VISION_THRESHOLDS
 * @param {number} now - Date.now() from the caller (kept as a param so this
 *   stays pure and testable without mocking the clock)
 * @returns {Array<{type,severity,message,value,threshold}>} active conditions
 */
function evaluateVisionSnapshot(records, thresholds, now) {
  const t = { ...DEFAULT_VISION_THRESHOLDS, ...thresholds };
  const current = records[records.length - 1];
  const prior = records.slice(0, -1);
  const out = [];

  // --- staleness: time-based, independent of everything else ---
  const ageMin = (now - current.timestamp) / 60000;
  if (ageMin > t.staleMinutes) {
    out.push({
      type: 'vision_stale',
      severity: 'warning',
      message: `No new AI analysis in ${Math.round(ageMin)} min — check the camera / desktop analyzer.`,
      value: Math.round(ageMin),
      threshold: t.staleMinutes,
    });
    // Data this old shouldn't drive biological alarms — they may no longer hold.
    return out;
  }

  const unhealthyCritical = current.unhealthyPct >= t.unhealthyCriticalPct;
  const unhealthyWarn = current.unhealthyPct >= t.unhealthyWarnPct;

  const activityLowSustained = lastNAllTrue(
    records, t.activityLowSustainedCount, r => r.activityLevel === 'low'
  );

  const birdBaseline = median(prior.slice(-5).map(r => r.birdCount));
  const dropFloor = birdBaseline != null ? birdBaseline * (1 - t.birdCountDropPct / 100) : null;
  const birdCountDropSustained =
    dropFloor != null &&
    lastNAllTrue(records, t.birdCountSustainedCount, r => r.birdCount <= dropFloor);

  const feedingStalledSustained = lastNAllTrue(
    records, t.feedingSustainedCount, r => r.eatDrinkPct < t.feedingStalledPct
  );

  const priorRatios = prior.slice(-5)
    .filter(r => r.birdCount > 0)
    .map(r => r.hotspotIntensity / r.birdCount);
  const ratioBaseline = median(priorRatios);
  const currentRatio = current.birdCount > 0 ? current.hotspotIntensity / current.birdCount : 0;
  const overcrowdingSpike =
    priorRatios.length >= 3 && ratioBaseline > 0 &&
    currentRatio >= ratioBaseline * t.hotspotSpikeRatio;

  // Fused conditions win over their standalone parts — one clear critical
  // alert beats two overlapping ones for the same underlying event.
  const combinedHealthActivity = unhealthyWarn && activityLowSustained;
  const combinedMortalityRisk = birdCountDropSustained && unhealthyWarn;

  if (combinedMortalityRisk) {
    out.push({
      type: 'vision_combined_mortality_risk',
      severity: 'critical',
      message: `Bird count dropped to ${current.birdCount} (baseline ~${Math.round(birdBaseline)}) while unhealthy rate is ${current.unhealthyPct.toFixed(1)}% — possible mortality event.`,
      value: current.birdCount,
      threshold: Math.round(dropFloor),
    });
  } else if (birdCountDropSustained) {
    out.push({
      type: 'vision_bird_count_drop',
      severity: 'critical',
      message: `Tracked bird count dropped to ${current.birdCount}, more than ${t.birdCountDropPct}% below the recent baseline (~${Math.round(birdBaseline)}).`,
      value: current.birdCount,
      threshold: Math.round(dropFloor),
    });
  }

  // Mortality risk already communicates the unhealthy rate in its own
  // message, so it suppresses the standalone rate/activity alerts too —
  // otherwise every mortality event doubles up with a redundant warning.
  const suppressIndividualHealthActivity = combinedHealthActivity || combinedMortalityRisk;

  if (combinedHealthActivity && !combinedMortalityRisk) {
    out.push({
      type: 'vision_combined_health_activity_risk',
      severity: 'critical',
      message: `Unhealthy rate ${current.unhealthyPct.toFixed(1)}% together with sustained low activity — inactivity may indicate illness rather than rest.`,
      value: current.unhealthyPct,
      threshold: t.unhealthyWarnPct,
    });
  } else if (!suppressIndividualHealthActivity) {
    if (unhealthyCritical || unhealthyWarn) {
      out.push({
        type: 'vision_unhealthy_rate',
        severity: unhealthyCritical ? 'critical' : 'warning',
        message: `Unhealthy detection rate at ${current.unhealthyPct.toFixed(1)}% (${current.unhealthy}/${current.healthy + current.unhealthy} birds).`,
        value: current.unhealthyPct,
        threshold: unhealthyCritical ? t.unhealthyCriticalPct : t.unhealthyWarnPct,
      });
    }
    if (activityLowSustained) {
      out.push({
        type: 'vision_activity_low',
        severity: 'warning',
        message: `Activity level has been low for ${t.activityLowSustainedCount} consecutive sessions.`,
        value: 0,
        threshold: t.activityLowSustainedCount,
      });
    }
  }

  if (overcrowdingSpike) {
    out.push({
      type: 'vision_overcrowding',
      severity: 'warning',
      message: `Activity-hotspot intensity per bird spiked to ${currentRatio.toFixed(2)} (~${(currentRatio / ratioBaseline).toFixed(1)}x recent baseline) near row ${current.hotspotRow}, col ${current.hotspotCol} — possible crowding/huddling.`,
      value: Number(currentRatio.toFixed(2)),
      threshold: Number((ratioBaseline * t.hotspotSpikeRatio).toFixed(2)),
    });
  }

  if (feedingStalledSustained) {
    out.push({
      type: 'vision_feeding_stalled',
      severity: 'critical',
      message: `Eat/drink activity has been under ${t.feedingStalledPct}% for ${t.feedingSustainedCount} consecutive sessions — check feeder/waterer.`,
      value: current.eatDrinkPct,
      threshold: t.feedingStalledPct,
    });
  }

  return out;
}
