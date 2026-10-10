// Bug 8 + Bug 9 regression guards.
//
// Bug 8 — the connectivity precheck timeout of 2 seconds was too aggressive
// for cold connections on mobile networks. Every actuator command fired this
// check, so users saw frequent spurious "Phone is offline" errors. The
// timeout must be at least 5 seconds (matches the meta-read timeout).
//
// Bug 9 — setControlMode duplicated the safetyOverride check inline instead
// of calling the shared `_guardSafety()` helper. Two Firebase reads, and
// the guard logic could drift from the actuator setters. Production code
// must reuse the helper.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/devices/providers/device_provider.dart',
  ).readAsStringSync();

  String _extractMethod(String methodName) {
    final startIdx = source.indexOf('Future<void> $methodName(');
    if (startIdx == -1) return '';
    int depth = 0;
    int i = startIdx;
    bool started = false;
    while (i < source.length) {
      if (source[i] == '{') {
        depth++;
        started = true;
      } else if (source[i] == '}') {
        depth--;
        if (started && depth == 0) return source.substring(startIdx, i + 1);
      }
      i++;
    }
    return source.substring(startIdx);
  }

  group('_ensureRealtimeConnected timeout (Bug 8)', () {
    final body = _extractMethod('_ensureRealtimeConnected');

    test('precheck timeout is at least 5 seconds', () {
      // Anything ≤ 4 seconds triggers spurious "offline" on slow networks.
      final m = RegExp(r'Duration\(seconds:\s*(\d+)\)').firstMatch(body);
      expect(m, isNotNull, reason: 'timeout duration not found in helper');
      final seconds = int.parse(m!.group(1)!);
      expect(seconds, greaterThanOrEqualTo(5),
          reason:
              'Connectivity precheck timeout must be ≥5s; 2s false-fails on '
              'slow networks and breaks every actuator command');
    });
  });

  group('setControlMode delegates to _guardSafety (Bug 9)', () {
    final body = _extractMethod('setControlMode');

    test('body calls _guardSafety() instead of inlining the check', () {
      expect(body, contains('_guardSafety'),
          reason: 'setControlMode must reuse the shared safety guard helper '
              'so the check cannot drift from the actuator setters');
    });

    test('body does NOT inline its own safetyOverride read', () {
      // Inlining causes two Firebase reads per call and the check duplicates
      // logic. The inline form was:
      //   final snapshot = await _farm.child('control/state').get();
      //   final safetyOverride = snapshot.child('safetyOverride')...
      expect(
        body.contains("snapshot.child('safetyOverride')"),
        isFalse,
        reason: 'setControlMode must not read safetyOverride inline — '
            'delegate to _guardSafety() instead',
      );
    });
  });
}
