/// Device metadata and configuration model
/// 
/// This model represents device information and configuration
/// that is synchronized between ESP32 and the mobile app.
class DeviceMetadata {
  final String deviceName;
  final String firmware;
  final String status;
  final String owner;
  final int lastSeen;
  final int startupTime;
  final SensorThresholds? thresholds;

  DeviceMetadata({
    required this.deviceName,
    required this.firmware,
    required this.status,
    required this.owner,
    required this.lastSeen,
    required this.startupTime,
    this.thresholds,
  });

  factory DeviceMetadata.fromMap(Map<String, dynamic> m) {
    return DeviceMetadata(
      deviceName: m['deviceName'] ?? 'Unknown Device',
      firmware: m['firmware'] ?? 'unknown',
      status: m['status'] ?? 'offline',
      owner: m['owner'] ?? 'unknown',
      lastSeen: (m['lastSeen'] ?? 0) is int 
          ? (m['lastSeen'] ?? 0) as int 
          : (m['lastSeen'] ?? 0).toInt(),
      startupTime: (m['startupTime'] ?? 0) is int 
          ? (m['startupTime'] ?? 0) as int 
          : (m['startupTime'] ?? 0).toInt(),
      thresholds: m['thresholds'] != null
          ? SensorThresholds.fromMap(Map<String, dynamic>.from(m['thresholds'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'deviceName': deviceName,
        'firmware': firmware,
        'status': status,
        'owner': owner,
        'lastSeen': lastSeen,
        'startupTime': startupTime,
        'thresholds': thresholds?.toMap(),
      };

  /// Freshness window: a device is "online" only if its last heartbeat is
  /// within this many milliseconds. Shared with DeviceRepository so both
  /// `DeviceSnapshot.isOnline` and `DeviceMetadata.isOnline` agree.
  static const int onlineWindowMs = 45000;

  /// Check if device is online (last seen within [onlineWindowMs]).
  bool get isOnline {
    if (lastSeen <= 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - lastSeen < onlineWindowMs;
  }

  /// Get human-readable last seen time
  String get lastSeenString {
    final lastSeenTime = DateTime.fromMillisecondsSinceEpoch(lastSeen);
    final now = DateTime.now();
    final difference = now.difference(lastSeenTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

/// Sensor thresholds for automatic control
/// SYNCHRONIZED with ESP32 defaults in main.c
class SensorThresholds {
  final double temperatureHigh;
  final double temperatureLow;
  final double humidityHigh;
  final double humidityLow;
  final double gasHigh;
  final double hysteresis; // Prevent rapid oscillation

  // SAFETY LIMITS - Cannot be overridden (matches ESP32 firmware config.h)
  // Based on poultry farming standards (Aviagen, USDA, FAO)
  static const double tempAbsoluteMin = 10.0;    // Death risk below 10°C
  static const double tempAbsoluteMax = 42.0;    // Heat stroke risk above 42°C
  static const double humidityAbsoluteMin = 30.0; // Respiratory issues & dust
  static const double humidityAbsoluteMax = 85.0; // Mold growth & ammonia buildup
  // Matches firmware GAS_ABS_MAX (config.h) — must stay below the MQ135
  // driver's own reading ceiling (500ppm) or the safety cutoff is a no-op.
  static const double gasAbsoluteMax = 450.0;

  // Recommended ranges for poultry farming
  static const double tempMin = 15.0;
  static const double tempMax = 40.0;
  static const double humidityMin = 30.0;
  static const double humidityMax = 95.0;
  static const double gasMax = 500.0; // Matches MQ135's own reading ceiling

  // Default values - MUST match ESP32 firmware (config.h)
  // Optimized for adult broilers (5+ weeks)
  static const double defaultTempHigh = 24.0;     // Heat stress above 25°C for adults
  static const double defaultTempLow = 18.0;      // Adult bird minimum comfort
  static const double defaultHumidityHigh = 70.0; // Wet litter & ammonia concerns
  static const double defaultHumidityLow = 50.0;  // Dust & respiratory issues
  static const double defaultGasHigh = 400.0;     // Matches firmware GAS_HIGH default
  static const double defaultHysteresis = 1.5;    // Tight control for stable environment

  SensorThresholds({
    required this.temperatureHigh,
    required this.temperatureLow,
    required this.humidityHigh,
    required this.humidityLow,
    required this.gasHigh,
    this.hysteresis = defaultHysteresis,
  });

  factory SensorThresholds.fromMap(Map<String, dynamic> m) {
    // Helper to safely convert to double with fallback
    double safeDouble(dynamic value, double fallback) {
      if (value == null) return fallback;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    return SensorThresholds(
      temperatureHigh: safeDouble(m['temperatureHigh'], defaultTempHigh),
      temperatureLow: safeDouble(m['temperatureLow'], defaultTempLow),
      humidityHigh: safeDouble(m['humidityHigh'], defaultHumidityHigh),
      humidityLow: safeDouble(m['humidityLow'], defaultHumidityLow),
      gasHigh: safeDouble(m['gasHigh'], defaultGasHigh),
      hysteresis: safeDouble(m['hysteresis'], defaultHysteresis),
    );
  }

  Map<String, dynamic> toMap() => {
        'temperatureHigh': temperatureHigh,
        'temperatureLow': temperatureLow,
        'humidityHigh': humidityHigh,
        'humidityLow': humidityLow,
        'gasHigh': gasHigh,
        'hysteresis': hysteresis,
      };

  /// Validate thresholds are within safe ranges. Returns an error key (not
  /// a display string) — this model has no BuildContext to localize with,
  /// so callers map the key to text via [describeThresholdValidationError]
  /// at the point where it's actually rendered.
  ThresholdValidationError? validate() {
    if (temperatureLow >= temperatureHigh) {
      return ThresholdValidationError.tempLowGteHigh;
    }
    if (temperatureHigh - temperatureLow < 2.0) {
      return ThresholdValidationError.tempRangeTooNarrow;
    }
    if (temperatureLow < tempMin || temperatureHigh > tempMax) {
      return ThresholdValidationError.tempOutOfRange;
    }
    if (humidityLow >= humidityHigh) {
      return ThresholdValidationError.humidityLowGteHigh;
    }
    if (humidityHigh - humidityLow < 5.0) {
      return ThresholdValidationError.humidityRangeTooNarrow;
    }
    if (humidityLow < humidityMin || humidityHigh > humidityMax) {
      return ThresholdValidationError.humidityOutOfRange;
    }
    if (gasHigh < 1.0 || gasHigh > gasMax) {
      return ThresholdValidationError.gasOutOfRange;
    }
    if (hysteresis < 0.5 || hysteresis > 10.0) {
      return ThresholdValidationError.hysteresisOutOfRange;
    }
    return null; // Valid
  }

  /// Check if thresholds are safe for poultry
  bool get isSafe {
    return validate() == null;
  }

  /// Get threshold status for a given temperature
  /// - Critical: Exceeds safety limits (TEMP_ABSOLUTE_MIN/MAX from firmware)
  /// - Warning: Exceeds operational thresholds but within safety limits
  /// - Normal: Within operational thresholds
  ThresholdStatus getTemperatureStatus(double value) {
    // Check safety limits first (CRITICAL - matches firmware lines 41-42)
    if (value < tempAbsoluteMin) return ThresholdStatus.criticalLow;
    if (value > tempAbsoluteMax) return ThresholdStatus.criticalHigh;
    
    // Check operational thresholds (WARNING - matches firmware lines 31-32)
    if (value < temperatureLow) return ThresholdStatus.low;
    if (value > temperatureHigh) return ThresholdStatus.high;
    
    return ThresholdStatus.normal;
  }

  /// Get threshold status for a given humidity
  /// - Critical: Exceeds safety limits (HUMIDITY_ABSOLUTE_MIN/MAX from firmware)
  /// - Warning: Exceeds operational thresholds but within safety limits
  /// - Normal: Within operational thresholds
  ThresholdStatus getHumidityStatus(double value) {
    // Check safety limits first (CRITICAL - matches firmware lines 43-44)
    if (value < humidityAbsoluteMin) return ThresholdStatus.criticalLow;
    if (value > humidityAbsoluteMax) return ThresholdStatus.criticalHigh;
    
    // Check operational thresholds (WARNING - matches firmware lines 33-34)
    if (value < humidityLow) return ThresholdStatus.low;
    if (value > humidityHigh) return ThresholdStatus.high;
    
    return ThresholdStatus.normal;
  }

  /// Get threshold status for gas level
  /// - Critical: Exceeds safety limit (matches firmware GAS_ABS_MAX)
  /// - Warning: Exceeds operational threshold but within safety limit
  /// - Normal: Within operational threshold
  ThresholdStatus getGasStatus(double value) {
    // Check safety limit first (CRITICAL - matches firmware line 44)
    if (value > gasAbsoluteMax) return ThresholdStatus.criticalHigh;
    
    // Check operational threshold (WARNING - matches firmware line 35)
    if (value > gasHigh) return ThresholdStatus.high;
    
    return ThresholdStatus.normal;
  }
}

/// Keys for [SensorThresholds.validate] — see that method's doc comment.
enum ThresholdValidationError {
  tempLowGteHigh,
  tempRangeTooNarrow,
  tempOutOfRange,
  humidityLowGteHigh,
  humidityRangeTooNarrow,
  humidityOutOfRange,
  gasOutOfRange,
  hysteresisOutOfRange,
}

/// Threshold status enumeration
enum ThresholdStatus {
  criticalLow,
  low,
  normal,
  high,
  criticalHigh,
}

extension ThresholdStatusExtension on ThresholdStatus {
  String get displayName {
    switch (this) {
      case ThresholdStatus.criticalLow:
        return 'Critical Low';
      case ThresholdStatus.low:
        return 'Low';
      case ThresholdStatus.normal:
        return 'Normal';
      case ThresholdStatus.high:
        return 'High';
      case ThresholdStatus.criticalHigh:
        return 'Critical High';
    }
  }

  bool get isCritical {
    return this == ThresholdStatus.criticalLow || this == ThresholdStatus.criticalHigh;
  }

  bool get needsAction {
    return this != ThresholdStatus.normal;
  }
}
