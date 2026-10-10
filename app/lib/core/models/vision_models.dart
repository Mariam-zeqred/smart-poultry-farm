/// Data types for the vision AI alarm system.
///
/// Ported from vision_alerts_prototype/{vision-alert-engine,alerts-store}.js.
/// The one deliberate change from the JS version: conditions carry a type +
/// numeric params instead of a baked English message string, so the UI layer
/// can render the message in whatever locale is active (see
/// vision_alert_localizations.dart).
library;

/// Wire-compatible with the `type` string ESP32/vision alerts already use
/// in `farm/alerts` (see firmware/firebase_client.cpp:
/// firebase_sendAlert). Only the vision_* members are written by this app;
/// the sensor ones are included so the same enum can label any alert type
/// the alerts list encounters.
enum VisionAlertType {
  visionStale('vision_stale'),
  visionUnhealthyRate('vision_unhealthy_rate'),
  visionActivityLow('vision_activity_low'),
  visionBirdCountDrop('vision_bird_count_drop'),
  visionOvercrowding('vision_overcrowding'),
  visionFeedingStalled('vision_feeding_stalled'),
  visionCombinedHealthActivityRisk('vision_combined_health_activity_risk'),
  visionCombinedMortalityRisk('vision_combined_mortality_risk');

  final String wireValue;
  const VisionAlertType(this.wireValue);

  static VisionAlertType? fromWire(String? value) {
    for (final t in VisionAlertType.values) {
      if (t.wireValue == value) return t;
    }
    return null;
  }

  bool get isVisionType => wireValue.startsWith('vision_');
}

/// Mirrors DEFAULT_VISION_THRESHOLDS in vision-alert-engine.js.
class VisionThresholds {
  final double unhealthyWarnPct;
  final double unhealthyCriticalPct;
  final int activityLowSustainedCount;
  final double birdCountDropPct;
  final int birdCountSustainedCount;
  final double hotspotSpikeRatio;
  final double feedingStalledPct;
  final int feedingSustainedCount;
  final double staleMinutes;

  const VisionThresholds({
    this.unhealthyWarnPct = 15,
    this.unhealthyCriticalPct = 30,
    this.activityLowSustainedCount = 2,
    this.birdCountDropPct = 20,
    this.birdCountSustainedCount = 2,
    this.hotspotSpikeRatio = 1.8,
    this.feedingStalledPct = 3,
    this.feedingSustainedCount = 3,
    this.staleMinutes = 20,
  });

  static const defaults = VisionThresholds();

  factory VisionThresholds.fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return defaults;
    double d(String key, double fallback) {
      final v = m[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    int i(String key, int fallback) {
      final v = m[key];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return VisionThresholds(
      unhealthyWarnPct: d('unhealthyWarnPct', defaults.unhealthyWarnPct),
      unhealthyCriticalPct: d('unhealthyCriticalPct', defaults.unhealthyCriticalPct),
      activityLowSustainedCount: i('activityLowSustainedCount', defaults.activityLowSustainedCount),
      birdCountDropPct: d('birdCountDropPct', defaults.birdCountDropPct),
      birdCountSustainedCount: i('birdCountSustainedCount', defaults.birdCountSustainedCount),
      hotspotSpikeRatio: d('hotspotSpikeRatio', defaults.hotspotSpikeRatio),
      feedingStalledPct: d('feedingStalledPct', defaults.feedingStalledPct),
      feedingSustainedCount: i('feedingSustainedCount', defaults.feedingSustainedCount),
      staleMinutes: d('staleMinutes', defaults.staleMinutes),
    );
  }

  Map<String, dynamic> toMap() => {
        'unhealthyWarnPct': unhealthyWarnPct,
        'unhealthyCriticalPct': unhealthyCriticalPct,
        'activityLowSustainedCount': activityLowSustainedCount,
        'birdCountDropPct': birdCountDropPct,
        'birdCountSustainedCount': birdCountSustainedCount,
        'hotspotSpikeRatio': hotspotSpikeRatio,
        'feedingStalledPct': feedingStalledPct,
        'feedingSustainedCount': feedingSustainedCount,
        'staleMinutes': staleMinutes,
      };

  VisionThresholds copyWith({
    double? unhealthyWarnPct,
    double? unhealthyCriticalPct,
    int? activityLowSustainedCount,
    double? birdCountDropPct,
    int? birdCountSustainedCount,
    double? hotspotSpikeRatio,
    double? feedingStalledPct,
    int? feedingSustainedCount,
    double? staleMinutes,
  }) {
    return VisionThresholds(
      unhealthyWarnPct: unhealthyWarnPct ?? this.unhealthyWarnPct,
      unhealthyCriticalPct: unhealthyCriticalPct ?? this.unhealthyCriticalPct,
      activityLowSustainedCount: activityLowSustainedCount ?? this.activityLowSustainedCount,
      birdCountDropPct: birdCountDropPct ?? this.birdCountDropPct,
      birdCountSustainedCount: birdCountSustainedCount ?? this.birdCountSustainedCount,
      hotspotSpikeRatio: hotspotSpikeRatio ?? this.hotspotSpikeRatio,
      feedingStalledPct: feedingStalledPct ?? this.feedingStalledPct,
      feedingSustainedCount: feedingSustainedCount ?? this.feedingSustainedCount,
      staleMinutes: staleMinutes ?? this.staleMinutes,
    );
  }
}

/// One compact logged sample — mirrors compactRecord() in alerts-store.js.
/// Stored under `farm/vision/history/{timestamp}`.
class VisionRecord {
  final int timestamp;
  final int birdCount;
  final String activityLevel; // 'high' | 'medium' | 'low' | 'unknown'
  final double eatDrinkPct;
  final double hotspotIntensity;
  final int? hotspotRow;
  final int? hotspotCol;
  final int healthy;
  final int unhealthy;
  final double unhealthyPct;

  const VisionRecord({
    required this.timestamp,
    required this.birdCount,
    required this.activityLevel,
    required this.eatDrinkPct,
    required this.hotspotIntensity,
    this.hotspotRow,
    this.hotspotCol,
    required this.healthy,
    required this.unhealthy,
    required this.unhealthyPct,
  });

  /// Builds a compact record from a raw `PoultrySystem/vision/analysis`
  /// snapshot (behavior + health nested maps, same shape the desktop
  /// analyzer writes).
  factory VisionRecord.fromAnalysis(Map<dynamic, dynamic> analysis) {
    final b = (analysis['behavior'] as Map?) ?? const {};
    final h = (analysis['health'] as Map?) ?? const {};
    final breakdown = (b['behaviorBreakdown'] as Map?) ?? const {};
    final hotspot = (b['hotspot'] as Map?) ?? const {};

    double numOr(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;
    int intOr(dynamic v, int fallback) => v is num ? v.toInt() : fallback;

    return VisionRecord(
      timestamp: intOr(analysis['timestamp'], 0),
      birdCount: intOr(b['birdCount'], 0),
      activityLevel: (b['activityLevel'] as String?) ?? 'unknown',
      eatDrinkPct: (numOr(breakdown['eatDrink'], 0) * 1000).round() / 10,
      hotspotIntensity: numOr(hotspot['intensity'], 0),
      hotspotRow: hotspot['row'] is num ? (hotspot['row'] as num).toInt() : null,
      hotspotCol: hotspot['col'] is num ? (hotspot['col'] as num).toInt() : null,
      healthy: intOr(h['healthy'], 0),
      unhealthy: intOr(h['unhealthy'], 0),
      unhealthyPct: numOr(h['unhealthyPct'], 0),
    );
  }

  factory VisionRecord.fromMap(Map<dynamic, dynamic> m) {
    double numOr(dynamic v, double fallback) => v is num ? v.toDouble() : fallback;
    int intOr(dynamic v, int fallback) => v is num ? v.toInt() : fallback;
    return VisionRecord(
      timestamp: intOr(m['timestamp'], 0),
      birdCount: intOr(m['birdCount'], 0),
      activityLevel: (m['activityLevel'] as String?) ?? 'unknown',
      eatDrinkPct: numOr(m['eatDrinkPct'], 0),
      hotspotIntensity: numOr(m['hotspotIntensity'], 0),
      hotspotRow: m['hotspotRow'] is num ? (m['hotspotRow'] as num).toInt() : null,
      hotspotCol: m['hotspotCol'] is num ? (m['hotspotCol'] as num).toInt() : null,
      healthy: intOr(m['healthy'], 0),
      unhealthy: intOr(m['unhealthy'], 0),
      unhealthyPct: numOr(m['unhealthyPct'], 0),
    );
  }

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp,
        'birdCount': birdCount,
        'activityLevel': activityLevel,
        'eatDrinkPct': eatDrinkPct,
        'hotspotIntensity': hotspotIntensity,
        'hotspotRow': hotspotRow,
        'hotspotCol': hotspotCol,
        'healthy': healthy,
        'unhealthy': unhealthy,
        'unhealthyPct': unhealthyPct,
      };
}

/// One fired alarm condition. `params` carries whatever numbers the
/// localized message template needs to interpolate — see
/// VisionAlertLocalizations.messageFor.
class VisionCondition {
  final VisionAlertType type;
  final String severity; // 'warning' | 'critical' — matches Alert.severity
  final Map<String, num> params;
  final num value;
  final num threshold;

  const VisionCondition({
    required this.type,
    required this.severity,
    required this.params,
    required this.value,
    required this.threshold,
  });
}
