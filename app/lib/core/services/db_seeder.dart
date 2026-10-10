import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

/// Seeds the flat /farm/ schema for the single-prototype farm.
/// Idempotent: if `farm/meta` already exists, does nothing.
class DbSeeder {
  static Future<void> initializeFirebaseData() async {
    final database = FirebaseDatabase.instance.ref();

    try {
      final snapshot = await database.child('farm/meta').once();
      if (snapshot.snapshot.value != null) {
        debugPrint('Farm node already exists; skipping seed.');
        return;
      }

      debugPrint('Seeding initial farm schema...');
      final now = DateTime.now().millisecondsSinceEpoch;

      await database.child('farm/meta').set({
        'deviceName': 'Mr.Mahmoud_Device',
        'firmware': '1.2.0-arduino',
        'status': 'offline',
        'owner': 'prototype',
        'lastSeen': 0,
        'startupTime': 0,
        'registered': now,
      });

      await database.child('farm/sensors/latest').set({
        'temperature': 0.0,
        'humidity': 0.0,
        'gas': 0.0,
        'ts': 0,
      });

      await database.child('farm/control/state').set({
        'fanState': false,
        'coolerState': false,
        'heaterState': false,
        'humidifierState': false,
        'controlMode': 'automatic',
        'reason': 'Initial state',
        'safetyOverride': false,
        'appControlEnabled': true,
      });

      await database.child('farm/config/thresholds').set({
        'temperatureHigh': 24.0,
        'temperatureLow': 18.0,
        'humidityHigh': 70.0,
        'humidityLow': 50.0,
        'gasHigh': 400.0,
        'hysteresis': 1.5,
      });

      await database.child('farm/config/fanCycle').set({
        'enabled': false,
        'onSec': 3 * 3600,
        'offSec': 2 * 3600,
      });

      debugPrint('Farm schema seeded.');
    } catch (e) {
      debugPrint('Error seeding farm data: $e');
      // Non-fatal — ESP32 will create what it needs when it connects.
    }
  }
}
