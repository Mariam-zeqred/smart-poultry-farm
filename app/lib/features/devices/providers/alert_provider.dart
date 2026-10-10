import 'package:firebase_database/firebase_database.dart';
import '../../../core/models/alert_model.dart';

/// Repository for managing device alerts
class AlertRepository {
  final FirebaseDatabase _database;

  AlertRepository(this._database);

  /// Watch alerts for device (real-time stream)
  Stream<List<Alert>> watchAlerts({
    bool activeOnly = false,
    String? severityFilter,
    int? limit,
  }) {
    Query query = _database.ref('farm/alerts');

    // Apply ordering (most recent first)
    query = query.orderByChild('createdAt');

    // Apply limit if specified
    if (limit != null) {
      query = query.limitToLast(limit);
    }

    return query.onValue.map((event) {
      if (!event.snapshot.exists) {
        return <Alert>[];
      }

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <Alert>[];

      final alerts = <Alert>[];
      data.forEach((key, value) {
        if (value is Map) {
          final alert = Alert.fromMap(key.toString(), value);

          // Apply filters
          if (activeOnly && !alert.isActive) return;
          if (severityFilter != null && alert.severity != severityFilter) return;

          alerts.add(alert);
        }
      });

      // Sort by createdAt descending (most recent first)
      alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return alerts;
    });
  }

  /// Get active alerts count
  Stream<int> watchActiveAlertsCount() {
    return watchAlerts(activeOnly: true).map((alerts) => alerts.length);
  }

  /// Get critical alerts count
  Stream<int> watchCriticalAlertsCount() {
    return watchAlerts(activeOnly: true, severityFilter: 'critical')
        .map((alerts) => alerts.length);
  }

  /// Acknowledge an alert
  Future<void> acknowledgeAlert(String alertId) async {
    await _database.ref('farm/alerts/$alertId').update({
      'acknowledgedAt': ServerValue.timestamp,
    });
  }

  /// Resolve an alert
  Future<void> resolveAlert(String alertId) async {
    await _database.ref('farm/alerts/$alertId').update({
      'resolvedAt': ServerValue.timestamp,
    });
  }

  /// Delete an alert
  Future<void> deleteAlert(String alertId) async {
    await _database.ref('farm/alerts/$alertId').remove();
  }

  /// Delete all resolved alerts (cleanup)
  Future<void> deleteResolvedAlerts() async {
    final snapshot = await _database.ref('farm/alerts').get();
    
    if (!snapshot.exists) return;

    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return;

    final batch = <Future>[];
    
    data.forEach((key, value) {
      if (value is Map && value['resolvedAt'] != null) {
        batch.add(_database.ref('farm/alerts/$key').remove());
      }
    });

    await Future.wait(batch);
  }

  /// Resolve all alerts of a specific type
  Future<void> resolveAlertsByType(String type) async {
    final snapshot = await _database.ref('farm/alerts')
        .orderByChild('type')
        .equalTo(type)
        .get();
    
    if (!snapshot.exists) return;

    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return;

    final batch = <Future>[];
    
    data.forEach((key, value) {
      if (value is Map && value['resolvedAt'] == null) {
        batch.add(_database.ref('farm/alerts/$key').update({
          'resolvedAt': ServerValue.timestamp,
        }));
      }
    });

    await Future.wait(batch);
  }
}
