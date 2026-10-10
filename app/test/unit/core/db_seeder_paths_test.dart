// Lightweight static check: db_seeder must write to farm/* (post-migration),
// NEVER to the legacy devices/esp32_device/* paths.
//
// We don't spin up a fake Firebase here — we read the source file and assert
// the path strings present. This catches schema regressions in CI.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('db_seeder schema regression guard', () {
    final source =
        File('lib/core/services/db_seeder.dart').readAsStringSync();

    test('writes to farm/* paths', () {
      expect(source, contains("'farm/meta'"));
      expect(source, contains("'farm/sensors/latest'"));
      expect(source, contains("'farm/control/state'"));
      expect(source, contains("'farm/config/thresholds'"));
    });

    test('does NOT write to legacy devices/* paths', () {
      expect(source, isNot(contains("'devices'")));
      expect(source, isNot(contains('"devices"')));
    });

    test('seeded firmware version matches firmware ino constant', () {
      // Firmware reports 1.2.0-arduino; seeder must match so app metadata
      // doesn't show a stale "1.1.0-arduino" before the ESP first heartbeats.
      expect(source, contains("'1.2.0-arduino'"));
      expect(source, isNot(contains("'1.1.0-arduino'")));
    });
  });
}
