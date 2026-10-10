// Bug 6 + Bug 7 firmware regression guards (source scan).
//
// Bug 6 — the gas, extreme-cold, and extreme-heat safety branches all call
// `firebase_sendAlert(..., "critical", ...)` with rate-limiting via
// `alertReady(...)`. The two humidity branches did not, so the user got no
// push notification when humidity went critical — silent failure mode that
// can kill birds.
//
// Bug 7 — the HIGH HUMIDITY safety branch turned the heater ON. Heating
// already-hot, already-humid air worsens heat stress at exactly the
// threshold the safety code is trying to protect against. Heater must be
// OFF in this branch (matches the gas/extreme-heat patterns).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final ino = File(
    '../esp32_firmware_arduino/esp32_firmware_arduino.ino',
  ).readAsStringSync();

  String _section(String startMarker, String endMarker) {
    final start = ino.indexOf(startMarker);
    if (start == -1) return '';
    final end = ino.indexOf(endMarker, start);
    return end == -1 ? ino.substring(start) : ino.substring(start, end);
  }

  group('Humidity safety alerts (Bug 6 firmware side)', () {
    test('LOW HUMIDITY branch sends a firebase_sendAlert', () {
      final body = _section('// 4. LOW HUMIDITY', '// 5. HIGH HUMIDITY');
      expect(body, contains('firebase_sendAlert'),
          reason: 'Critical low humidity must push an alert to the user, '
              'matching the gas/temperature safety branches');
      expect(body, contains('alertReady(A_HUM_LO)'),
          reason:
              'Use the A_HUM_LO cooldown slot to prevent alert spam');
    });

    test('HIGH HUMIDITY branch sends a firebase_sendAlert', () {
      final body = _section('// 5. HIGH HUMIDITY', 'UNLOCK();\n    return false;');
      expect(body, contains('firebase_sendAlert'),
          reason: 'Critical high humidity must push an alert');
      expect(body, contains('alertReady(A_HUM_HI)'),
          reason:
              'Use the A_HUM_HI cooldown slot to prevent alert spam');
    });
  });

  group('High-humidity heater logic (Bug 7)', () {
    test('HIGH HUMIDITY branch does NOT turn heater on', () {
      final body = _section('// 5. HIGH HUMIDITY', 'UNLOCK();\n    return false;');
      // The previous (buggy) line was: `fanOn = true; heaterOn = true;`
      // Heating already-humid air worsens heat stress on the birds.
      expect(body, contains('heaterOn = false'),
          reason: 'High humidity branch must set heaterOn = false; '
              'heating cannot safely lower humidity at >85% RH and '
              'compounds heat stress on the birds');
      expect(body, contains('fanOn = true'),
          reason: 'Fan must stay ON to ventilate the moist air');
    });
  });
}
