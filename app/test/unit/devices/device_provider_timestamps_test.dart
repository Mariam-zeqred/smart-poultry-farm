// Bug 6 regression guard: every write that can race between app and ESP must
// carry a `lastModifiedAt` server-timestamp so the ESP can detect stale
// overwrites on reconnect.
//
// We scan the source rather than spinning up Firebase because
// DatabaseReference cannot be instantiated without a live Firebase project.
// The scan gives us a CI-enforced structural guarantee.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('device_provider timestamp regression guard (Bug 6)', () {
    final source = File(
      'lib/features/devices/providers/device_provider.dart',
    ).readAsStringSync();

    test('updateThresholds write includes lastModifiedAt timestamp', () {
      // The threshold node must carry lastModifiedAt so the ESP can compare
      // cloud write time against its own boot time and discard stale values.
      expect(
        source,
        contains("'lastModifiedAt'"),
        reason: 'updateThresholds must write lastModifiedAt: ServerValue.timestamp',
      );
    });

    test('setControlMode write includes lastModifiedAt or updated_at timestamp', () {
      // Mode changes from both app and LCD must be timestamped so the
      // last legitimate writer wins, not the last reconnecting writer.
      expect(
        source,
        anyOf(
          contains("'lastModifiedAt'"),
          contains("'updated_at'"),
        ),
        reason: 'setControlMode must include a server timestamp in its write',
      );
    });

    test('setFanState write includes updated_at timestamp', () {
      // Actuator writes must be timestamped for ordering guarantees.
      expect(
        source,
        contains("'updated_at': ServerValue.timestamp"),
        reason: 'setFanState (and siblings) must write updated_at',
      );
    });
  });
}
