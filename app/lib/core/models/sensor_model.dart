/// Data models for the live sensor reading and the actuator control state.
///
/// Field names mirror the Firebase Realtime Database schema written by the
/// ESP32 firmware exactly (see docs/FIREBASE_SCHEMA.md):
///   * `farm/sensors/latest`   -> [SensorLatest]
///   * `farm/control/state`    -> [ControlState]
///   * `farm/config/fanCycle`  -> [FanCycleConfig]
///
/// Parsing is defensive on purpose: the firmware writes numbers, but seeded or
/// hand-edited data may contain strings or nulls, and a bad value must never
/// crash the dashboard.
library;

class SensorLatest {
  final double temperature;
  final double humidity;
  final double gas;
  final int ts;

  SensorLatest({
    required this.temperature,
    required this.humidity,
    required this.gas,
    required this.ts,
  });

  factory SensorLatest.fromMap(Map<String, dynamic> m) {
    // Helper to safely convert to double
    double safeDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return SensorLatest(
      temperature: safeDouble(m['temperature']),
      humidity: safeDouble(m['humidity']),
      gas: safeDouble(m['gas']),
      ts: (m['ts'] ?? 0) is int ? (m['ts'] ?? 0) as int : 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'temperature': temperature,
        'humidity': humidity,
        'gas': gas,
        'ts': ts,
      };
}

class ControlState {
  final bool fanState;         // ON/OFF
  final bool coolerState;      // ON/OFF
  final bool heaterState;      // ON/OFF
  final bool humidifierState;  // ON/OFF
  final String? controlMode; // manual/automatic
  final String? reason;    // reason for control action
  final bool? safetyOverride; // true when safety limits force control (cannot be overridden by user)
  // Control ownership (2026-08-29): true = the app owns control (Farm
  // Control section is live, LCD is monitor-only); false = the LCD owns
  // control (Farm Control section greys out to monitor-only). Defaults
  // true so devices that predate this field, or a doc missing it, behave
  // exactly as before this feature existed — mirrors the firmware's own
  // default in applyControlStateDoc().
  final bool appControlEnabled;

  ControlState({
    required this.fanState,
    required this.coolerState,
    required this.heaterState,
    required this.humidifierState,
    this.controlMode,
    this.reason,
    this.safetyOverride,
    this.appControlEnabled = true,
  });

  factory ControlState.fromMap(Map<String, dynamic> m) {
    // Helper to safely convert to bool
    bool safeBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      return false;
    }

    return ControlState(
      fanState: safeBool(m['fanState']),
      coolerState: safeBool(m['coolerState']),
      heaterState: safeBool(m['heaterState']),
      humidifierState: safeBool(m['humidifierState']),
      controlMode: m['controlMode'] as String?,
      reason: m['reason'] as String?,
      safetyOverride: m['safetyOverride'] != null ? safeBool(m['safetyOverride']) : null,
      appControlEnabled: m['appControlEnabled'] == null ? true : safeBool(m['appControlEnabled']),
    );
  }

  Map<String, dynamic> toMap() => {
        'fanState': fanState,
        'coolerState': coolerState,
        'heaterState': heaterState,
        'humidifierState': humidifierState,
        'controlMode': controlMode,
        'reason': reason,
        'safetyOverride': safetyOverride,
        'appControlEnabled': appControlEnabled,
      };
}

/// Scheduled fan airing cycle (farm/config/fanCycle). When [enabled], the
/// firmware drives the Fan ON for [onSec] then OFF for [offSec], repeating,
/// independent of gas/temp/humidity — set via the app, evaluated locally by
/// the ESP32 (keeps running through a WiFi/Firebase outage).
class FanCycleConfig {
  final bool enabled;
  final int onSec;
  final int offSec;

  const FanCycleConfig({
    required this.enabled,
    required this.onSec,
    required this.offSec,
  });

  static const defaults = FanCycleConfig(
    enabled: false,
    onSec: 3 * 3600,
    offSec: 2 * 3600,
  );

  factory FanCycleConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    bool safeBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value != 0;
      return false;
    }

    return FanCycleConfig(
      enabled: safeBool(m['enabled']),
      onSec: (m['onSec'] as num?)?.toInt() ?? defaults.onSec,
      offSec: (m['offSec'] as num?)?.toInt() ?? defaults.offSec,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'onSec': onSec,
        'offSec': offSec,
      };

  FanCycleConfig copyWith({bool? enabled, int? onSec, int? offSec}) =>
      FanCycleConfig(
        enabled: enabled ?? this.enabled,
        onSec: onSec ?? this.onSec,
        offSec: offSec ?? this.offSec,
      );
}
