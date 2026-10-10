/**
 * Bridges the pure vision-alert-engine decisions to the REAL `farm/alerts`
 * schema the Flutter app and ESP32 firmware already use (see
 * esp32_firmware/firebase_client.cpp: type, severity, message, value,
 * threshold, createdAt). Vision-origin alerts are just more rows in the
 * same collection, tagged with deviceId "vision-ai" so the UI can tell them
 * apart from sensor alerts if it wants to.
 *
 * Also maintains `farm/vision/history/{timestamp}` — a compact log the
 * desktop analyzer does NOT write (it only overwrites a single "latest"
 * snapshot). We need this history for sustained/baseline rules (bird-count
 * drop vs. rolling median, overcrowding vs. rolling per-bird ratio) and it
 * doubles as the data for the trend sparkline in the UI.
 */

const VISION_DEVICE_ID = 'vision-ai';
const HISTORY_WINDOW = 8;

const BASE_SNAPSHOT = {
  behavior: {
    activityLevel: 'high',
    birdCount: 30,
    behaviorBreakdown: { eatDrink: 0.20, moving: 0.60, rest: 0.20 },
    avgDwellSeconds: { 'eat-drink': 0, moving: 0, rest: 0 },
    hotspot: { row: 12, col: 8, intensity: 55 },
    topTransitions: [],
  },
  health: { healthy: 30, unhealthy: 0, unhealthyPct: 0, status: 'normal' },
  source: 'simulated',
  timestamp: 0,
};

// Scenario -> partial overrides merged onto BASE_SNAPSHOT.
const SCENARIOS = {
  normal: {},
  unhealthy_warning: { health: { healthy: 25, unhealthy: 5, unhealthyPct: 16.7, status: 'watch' } },
  unhealthy_critical: { health: { healthy: 18, unhealthy: 12, unhealthyPct: 40.0, status: 'alert' } },
  activity_low: { behavior: { activityLevel: 'low' } },
  bird_count_drop: { behavior: { birdCount: 18 } },
  overcrowding: { behavior: { hotspot: { row: 12, col: 8, intensity: 140 } } },
  feeding_stalled: { behavior: { behaviorBreakdown: { eatDrink: 0.01, moving: 0.70, rest: 0.29 } } },
  combined_mortality: {
    behavior: { birdCount: 16 },
    health: { healthy: 12, unhealthy: 4, unhealthyPct: 25.0, status: 'alert' },
  },
  stale: {},
};

// How many consecutive snapshots each scenario needs to actually cross its
// rule's sustained-count requirement (see DEFAULT_VISION_THRESHOLDS).
const SUSTAIN_REPEATS = {
  normal: 1,
  unhealthy_warning: 1,
  unhealthy_critical: 1,
  activity_low: 2,
  bird_count_drop: 2,
  overcrowding: 1, // spike-vs-baseline, not sustained — baseline priming covers it
  feeding_stalled: 3,
  combined_mortality: 2,
  stale: 1,
};

function deepMerge(target, source) {
  for (const key of Object.keys(source)) {
    const val = source[key];
    if (val && typeof val === 'object' && !Array.isArray(val)) {
      target[key] = deepMerge(target[key] ? { ...target[key] } : {}, val);
    } else {
      target[key] = val;
    }
  }
  return target;
}

function buildSnapshot(overrides, timestamp) {
  const merged = deepMerge(JSON.parse(JSON.stringify(BASE_SNAPSHOT)), overrides);
  merged.timestamp = timestamp;
  return merged;
}

function compactRecord(analysis) {
  const b = analysis.behavior || {};
  const h = analysis.health || {};
  const eatDrinkFrac = (b.behaviorBreakdown && b.behaviorBreakdown.eatDrink) || 0;
  return {
    timestamp: analysis.timestamp,
    birdCount: b.birdCount ?? 0,
    activityLevel: b.activityLevel ?? 'unknown',
    eatDrinkPct: Math.round(eatDrinkFrac * 1000) / 10,
    hotspotIntensity: (b.hotspot && b.hotspot.intensity) || 0,
    hotspotRow: (b.hotspot && b.hotspot.row) ?? null,
    hotspotCol: (b.hotspot && b.hotspot.col) ?? null,
    healthy: h.healthy ?? 0,
    unhealthy: h.unhealthy ?? 0,
    unhealthyPct: h.unhealthyPct ?? 0,
  };
}

async function fetchAllAlerts() {
  const data = await dbGet('farm/alerts');
  if (!data) return [];
  return Object.entries(data).map(([id, v]) => ({ id, ...v }));
}

async function fetchVisionHistory(limit = HISTORY_WINDOW) {
  const data = await dbGet('farm/vision/history');
  if (!data) return [];
  const records = Object.values(data).sort((a, b) => a.timestamp - b.timestamp);
  return records.slice(-limit);
}

async function fetchVisionThresholds() {
  const data = await dbGet('farm/config/visionThresholds');
  return { ...DEFAULT_VISION_THRESHOLDS, ...(data || {}) };
}

async function saveVisionThresholds(values) {
  await dbPut('farm/config/visionThresholds', values);
}

async function acknowledgeAlert(id) {
  await dbPatch(`farm/alerts/${id}`, { acknowledgedAt: serverTimestamp() });
}

async function resolveAlert(id) {
  await dbPatch(`farm/alerts/${id}`, { resolvedAt: serverTimestamp() });
}

/** Upsert firing conditions into farm/alerts; resolve ones that cleared. */
async function reconcileAlerts(conditions) {
  const all = await fetchAllAlerts();
  const activeByType = new Map();
  for (const a of all) {
    if (a.type && a.type.startsWith('vision_') && !a.resolvedAt) {
      activeByType.set(a.type, a);
    }
  }

  const firingTypes = new Set(conditions.map(c => c.type));

  for (const c of conditions) {
    const existing = activeByType.get(c.type);
    if (existing) {
      await dbPatch(`farm/alerts/${existing.id}`, {
        severity: c.severity,
        message: c.message,
        value: c.value,
        threshold: c.threshold,
        lastSeenAt: serverTimestamp(),
      });
    } else {
      await dbPost('farm/alerts', {
        type: c.type,
        severity: c.severity,
        message: c.message,
        value: c.value,
        threshold: c.threshold,
        createdAt: serverTimestamp(),
        lastSeenAt: serverTimestamp(),
        deviceId: VISION_DEVICE_ID,
      });
    }
  }

  for (const [type, alert] of activeByType) {
    if (!firingTypes.has(type)) {
      await dbPatch(`farm/alerts/${alert.id}`, { resolvedAt: serverTimestamp() });
    }
  }
}

/**
 * Serializes every evaluation/reset call within this page. Plain REST has
 * no transaction primitive, so reconcileAlerts' "read active alerts, then
 * create/patch" is a check-then-act race: the 8s background poller and an
 * in-flight simulateScenario() (which itself calls processLatestSnapshot
 * several times) can interleave, both see "no alert of this type yet", and
 * both POST — producing duplicate rows. Chaining every call through one
 * promise queue makes them run one-at-a-time in this tab, which is enough
 * for the single-evaluator design this prototype assumes. It does NOT
 * protect against two separate tabs/clients evaluating at once — that
 * would need a real Firebase transaction or a single server-side owner.
 */
let _evalLock = Promise.resolve();
function withEvalLock(fn) {
  const run = _evalLock.then(fn, fn);
  _evalLock = run.then(() => {}, () => {});
  return run;
}

/** Fetch the latest analyzer snapshot, log it, evaluate rules, reconcile alerts. */
function processLatestSnapshot(thresholdsOverride) {
  return withEvalLock(() => _processLatestSnapshotLocked(thresholdsOverride));
}

async function _processLatestSnapshotLocked(thresholdsOverride) {
  const analysis = await dbGet('PoultrySystem/vision/analysis');
  if (!analysis || !analysis.timestamp) return { processed: false, reason: 'no-data' };

  const record = compactRecord(analysis);
  const alreadyLogged = await dbGet(`farm/vision/history/${record.timestamp}`);
  if (!alreadyLogged) {
    await dbPut(`farm/vision/history/${record.timestamp}`, record);
  }

  // `record` is always treated as "current" and placed last structurally
  // (not by sort-on-value) — the one deliberately out-of-order case is the
  // `stale` simulate scenario, which sets an old timestamp on purpose to
  // represent a snapshot that arrived late/never got superseded.
  const history = await fetchVisionHistory();
  const priorOnly = history.filter(r => r.timestamp !== record.timestamp);
  const records = [...priorOnly, record];

  const thresholds = thresholdsOverride || (await fetchVisionThresholds());
  const conditions = evaluateVisionSnapshot(records, thresholds, Date.now());
  await reconcileAlerts(conditions);

  return { processed: true, analysis, record, records, conditions };
}

const STEP_MS = 5 * 60 * 1000; // 5 "minutes" apart, purely for distinct/ordered keys
const LOOKBACK_MS = 6 * STEP_MS;

/**
 * Picks a starting timestamp for a new priming sequence that is always
 * AFTER whatever is already in farm/vision/history. Using a plain
 * `Date.now() - offset` per click seems fine in isolation, but two
 * simulate clicks run seconds apart both compute their "30 minutes ago"
 * priming points independently — those points land almost on top of each
 * other and can sort *before* the previous click's more recent entries,
 * corrupting the rolling-median baseline the next scenario reads. Anchoring
 * to the last logged timestamp keeps every click's history strictly
 * increasing, same as real analyzer sessions would be.
 */
async function nextBaseTimestamp() {
  const hist = await fetchVisionHistory(1);
  const lastTs = hist.length ? hist[0].timestamp : 0;
  const desiredStart = Date.now() - LOOKBACK_MS;
  return Math.max(desiredStart, lastTs + 1000);
}

/**
 * Wipes the synthetic test log and any vision-origin alerts. Repeated
 * simulate clicks push each new priming sequence's timestamps after the
 * last one on record (see nextBaseTimestamp) so ordering stays consistent —
 * but across a long test session that walks the "current" reading further
 * into the future each click. Harmless to the alarm logic, just makes
 * "last updated" read oddly after a lot of clicking. Reset clears it back
 * to a blank slate. Does NOT touch real sensor data under farm/*.
 */
function resetVisionTestData() {
  return withEvalLock(async () => {
    await dbDelete('farm/vision/history');
    await dbDelete('PoultrySystem/vision/analysis');
    const all = await fetchAllAlerts();
    const visionAlertIds = all.filter(a => a.type && a.type.startsWith('vision_')).map(a => a.id);
    await Promise.all(visionAlertIds.map(id => dbDelete(`farm/alerts/${id}`)));
  });
}

/** Write a short priming history + the target scenario, then evaluate. */
async function simulateScenario(name) {
  // Staleness is evaluated purely from wall-clock age and short-circuits
  // before any history/baseline logic runs — priming would just be wasted
  // writes, and would fight the "always after the last entry" invariant
  // nextBaseTimestamp relies on for every other scenario.
  if (name === 'stale') {
    await dbPut('PoultrySystem/vision/analysis', buildSnapshot({}, Date.now() - 30 * 60 * 1000));
    return processLatestSnapshot();
  }

  let ts = await nextBaseTimestamp();

  // Baseline priming so relative rules (bird-count drop, overcrowding) have
  // something normal to compare against.
  for (let i = 0; i < 4; i++) {
    await dbPut('PoultrySystem/vision/analysis', buildSnapshot({}, ts));
    await processLatestSnapshot();
    ts += STEP_MS;
  }

  const overrides = SCENARIOS[name] || {};
  const repeats = SUSTAIN_REPEATS[name] || 1;
  let result;
  for (let i = 0; i < repeats; i++) {
    await dbPut('PoultrySystem/vision/analysis', buildSnapshot(overrides, ts));
    result = await processLatestSnapshot();
    ts += STEP_MS;
  }
  return result;
}
