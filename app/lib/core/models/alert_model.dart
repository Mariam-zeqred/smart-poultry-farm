/// Alert model for threshold breach notifications
class Alert {
  final String id;
  final String type;
  final String severity; // 'info', 'warning', 'critical'
  final String message;
  final double value;
  final double threshold;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;

  /// Structured numeric data for locale-independent message rendering.
  /// Only populated by vision-origin alerts (see VisionAlertLocalization in
  /// vision_alert_localizations.dart) — sensor alerts written by the ESP32
  /// firmware don't set this, so [message] stays their source of truth.
  final Map<String, num>? params;

  const Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    required this.value,
    required this.threshold,
    required this.createdAt,
    this.acknowledgedAt,
    this.resolvedAt,
    this.params,
  });

  /// Create Alert from Firebase snapshot
  factory Alert.fromMap(String id, Map<dynamic, dynamic> map) {
    return Alert(
      id: id,
      type: map['type'] as String? ?? 'unknown',
      severity: map['severity'] as String? ?? 'info',
      message: map['message'] as String? ?? '',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      threshold: (map['threshold'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? 0,
      ),
      acknowledgedAt: map['acknowledgedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['acknowledgedAt'] as num).toInt(),
            )
          : null,
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['resolvedAt'] as num).toInt(),
            )
          : null,
      params: map['params'] is Map
          ? (map['params'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num?) ?? 0),
            )
          : null,
    );
  }

  /// Convert Alert to Firebase map
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'severity': severity,
      'message': message,
      'value': value,
      'threshold': threshold,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'acknowledgedAt': acknowledgedAt?.millisecondsSinceEpoch,
      'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
      if (params != null) 'params': params,
    };
  }

  /// Check if alert is acknowledged
  bool get isAcknowledged => acknowledgedAt != null;

  /// Check if alert is resolved
  bool get isResolved => resolvedAt != null;

  /// Check if alert is active (not resolved)
  bool get isActive => !isResolved;

  /// Get severity icon
  String get severityIcon {
    switch (severity) {
      case 'critical':
        return '🚨';
      case 'warning':
        return '⚠️';
      case 'info':
        return 'ℹ️';
      default:
        return '📢';
    }
  }

  /// Get alert type display name
  ///
  /// The 'temperature_high'/'humidity_high'/'gas_detected'-style cases below
  /// were written against an alert-type naming convention the ESP32
  /// firmware never actually uses — it only ever posts the
  /// 'xxx_critical'/'critical_xxx'-style types below (all severity
  /// 'critical', from checkSafety()'s hard safety limits). Every real
  /// device alert was falling through to the generic fallback formatter.
  /// Both sets are kept: the firmware-accurate ones so real alerts get a
  /// proper label, the older ones in case any historical/seeded data still
  /// uses that convention.
  String get typeDisplayName {
    switch (type) {
      case 'gas_critical':
        return 'Dangerous Gas Level';
      case 'temp_critical_low':
        return 'Critical Low Temperature';
      case 'temp_critical_high':
        return 'Critical High Temperature';
      case 'hum_critical_low':
        return 'Critical Low Humidity';
      case 'hum_critical_high':
        return 'Critical High Humidity';
      case 'temperature_high':
        return 'High Temperature';
      case 'temperature_low':
        return 'Low Temperature';
      case 'humidity_high':
        return 'High Humidity';
      case 'humidity_low':
        return 'Low Humidity';
      case 'gas_detected':
        return 'Gas Detection';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  /// Create a copy with updated fields
  Alert copyWith({
    String? id,
    String? type,
    String? severity,
    String? message,
    double? value,
    double? threshold,
    DateTime? createdAt,
    DateTime? acknowledgedAt,
    DateTime? resolvedAt,
    Map<String, num>? params,
  }) {
    return Alert(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      value: value ?? this.value,
      threshold: threshold ?? this.threshold,
      createdAt: createdAt ?? this.createdAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      params: params ?? this.params,
    );
  }

  @override
  String toString() {
    return 'Alert(id: $id, type: $type, severity: $severity, message: $message, '
        'value: $value, threshold: $threshold, createdAt: $createdAt, '
        'acknowledged: $isAcknowledged, resolved: $isResolved)';
  }
}
