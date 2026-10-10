import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/models/sensor_model.dart';

/// Provider for sensor history repository
final sensorHistoryRepoProvider = Provider<SensorHistoryRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SensorHistoryRepository(database);
});

/// History provider by selected range index:
/// 0 = 24h, 1 = 7d, 2 = 30d
final sensorHistoryRangeProvider = FutureProvider.family<List<SensorLatest>, int>((ref, rangeIndex) async {
  final repo = ref.watch(sensorHistoryRepoProvider);
  final now = DateTime.now();
  final start = switch (rangeIndex) {
    1 => now.subtract(const Duration(days: 7)),
    2 => now.subtract(const Duration(days: 30)),
    _ => now.subtract(const Duration(hours: 24)),
  };

  return repo.getHistory(startTime: start, endTime: now);
});

/// Repository for managing sensor historical data
class SensorHistoryRepository {
  final DatabaseReference _database;

  SensorHistoryRepository(this._database);

  /// Store sensor reading in history (called automatically when new reading arrives)
  Future<void> storeSensorReading(SensorLatest data) async {
    try {
      final timestamp = data.ts;
      final hourKey = _getHourKey(timestamp);

      await _database
          .child('farm/sensors/history')
          .child(hourKey)
          .push()
          .set({
        'temperature': data.temperature,
        'humidity': data.humidity,
        'gas': data.gas,
        'ts': timestamp,
      });
      
      print('✓ Sensor reading stored in history: $hourKey');
    } catch (e, stackTrace) {
      print('🔴 Error storing sensor history: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Get sensor history for a specific time range
  Future<List<SensorLatest>> getHistory({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final List<SensorLatest> allReadings = [];
      
      // Get all hour keys in the range
      final hourKeys = _getHourKeysInRange(startTime, endTime);
      
      for (final hourKey in hourKeys) {
        final snapshot = await _database
            .child('farm/sensors/history')
            .child(hourKey)
            .orderByChild('ts')
            .startAt(startTime.millisecondsSinceEpoch)
            .endAt(endTime.millisecondsSinceEpoch)
            .get();

        if (snapshot.value != null) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          for (final entry in data.entries) {
            final reading = Map<String, dynamic>.from(entry.value as Map);
            allReadings.add(SensorLatest(
              temperature: (reading['temperature'] as num?)?.toDouble() ?? 0.0,
              humidity: (reading['humidity'] as num?)?.toDouble() ?? 0.0,
              gas: (reading['gas'] as num?)?.toDouble() ?? 0.0,
              ts: reading['ts'] as int? ?? 0,
            ));
          }
        }
      }
      
      // Sort by timestamp
      allReadings.sort((a, b) => a.ts.compareTo(b.ts));
      
      print('✓ Retrieved ${allReadings.length} sensor readings');
      return allReadings;
    } catch (e, stackTrace) {
      print('🔴 Error getting sensor history: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get aggregated data for analytics (hourly averages)
  Future<List<Map<String, dynamic>>> getAggregatedHistory({
    required DateTime startTime,
    required DateTime endTime,
    required String aggregation, // 'hour', 'day'
  }) async {
    final readings = await getHistory(startTime: startTime, endTime: endTime);
    
    if (readings.isEmpty) return [];
    
    // Group by hour or day
    final Map<int, List<SensorLatest>> grouped = {};
    
    for (final reading in readings) {
      final timestamp = reading.ts;
      final key = aggregation == 'hour'
          ? (timestamp ~/ (3600 * 1000)) * 3600 * 1000
          : (timestamp ~/ (86400 * 1000)) * 86400 * 1000;
      
      grouped.putIfAbsent(key, () => []).add(reading);
    }
    
    // Calculate averages
    return grouped.entries.map((entry) {
      final readings = entry.value;
      final avgTemp = readings.map((r) => r.temperature).reduce((a, b) => a + b) / readings.length;
      final avgHumidity = readings.map((r) => r.humidity).reduce((a, b) => a + b) / readings.length;
      final avgGas = readings.map((r) => r.gas).reduce((a, b) => a + b) / readings.length;
      
      return {
        'timestamp': entry.key,
        'temperature': avgTemp,
        'humidity': avgHumidity,
        'gas': avgGas,
        'count': readings.length,
      };
    }).toList()
      ..sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
  }

  /// Clean up old history data (keep last 30 days)
  Future<void> cleanupOldHistory({int daysToKeep = 30}) async {
    try {
      final cutoffTime = DateTime.now().subtract(Duration(days: daysToKeep));
      final cutoffHourKey = _getHourKey(cutoffTime.millisecondsSinceEpoch);
      
      final snapshot =
          await _database.child('farm/sensors/history').get();

      if (snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        int deletedCount = 0;

        for (final hourKey in data.keys) {
          if (hourKey.compareTo(cutoffHourKey) < 0) {
            await _database
                .child('farm/sensors/history')
                .child(hourKey)
                .remove();
            deletedCount++;
          }
        }
        
        print('✓ Cleaned up $deletedCount old history entries');
      }
    } catch (e, stackTrace) {
      print('🔴 Error cleaning up history: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Get hour key for bucketing (format: YYYY-MM-DD-HH)
  String _getHourKey(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
           '${date.day.toString().padLeft(2, '0')}-'
           '${date.hour.toString().padLeft(2, '0')}';
  }

  /// Get all hour keys in a time range
  List<String> _getHourKeysInRange(DateTime start, DateTime end) {
    final keys = <String>[];
    var current = DateTime(start.year, start.month, start.day, start.hour);
    
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      keys.add(_getHourKey(current.millisecondsSinceEpoch));
      current = current.add(const Duration(hours: 1));
    }
    
    return keys;
  }
}
