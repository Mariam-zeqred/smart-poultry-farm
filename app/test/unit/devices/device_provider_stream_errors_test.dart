// Bug 5 regression guard: every Firebase stream listener inside
// `_combineDeviceStreams` must wire an `onError` handler that forwards the
// error to the merged StreamController. Without it, auth-expiry,
// permission-denied, and transient network errors are silently swallowed and
// the UI freezes on stale data with no indication anything is wrong.
//
// We source-scan because Firebase streams cannot be instantiated in unit
// tests without a live project.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('device_provider stream error propagation (Bug 5)', () {
    final source = File(
      'lib/features/devices/providers/device_provider.dart',
    ).readAsStringSync();

    // Extract the body of the `_combineDeviceStreams` METHOD by brace-matching.
    // Anchor on the method declaration (return type), not call sites.
    final start = source.indexOf('Stream<DeviceSnapshot> _combineDeviceStreams(');
    final openBrace = source.indexOf('{', start);
    int depth = 0;
    int i = openBrace;
    int end = -1;
    while (i < source.length) {
      if (source[i] == '{') depth++;
      else if (source[i] == '}') {
        depth--;
        if (depth == 0) {
          end = i + 1;
          break;
        }
      }
      i++;
    }
    final body = source.substring(start, end);

    // Count `.listen(` calls inside the helper.
    final listenCount = RegExp(r'\.listen\s*\(').allMatches(body).length;

    test('helper contains four .listen( subscriptions (baseline)', () {
      expect(listenCount, 4,
          reason: 'Sensors / control / meta / thresholds = 4 streams');
    });

    test('every .listen call wires an onError handler', () {
      // Every `.listen(` must be followed (within the same call) by an
      // `onError:` named argument before the closing paren of that listen.
      // A simpler structural check: the same number of `onError:` named
      // arguments must appear inside the helper as `.listen(` calls.
      final onErrorCount =
          RegExp(r'onError\s*:').allMatches(body).length;
      expect(onErrorCount, listenCount,
          reason:
              'Each listen() must pass onError: so Firebase errors propagate '
              'to the merged StreamController instead of being swallowed');
    });

    test('onError handler forwards to controller.addError', () {
      // The handler body must actually push the error to the controller —
      // a no-op `onError: (_) {}` would still pass the count test.
      expect(
        body,
        contains('controller.addError'),
        reason:
            'onError handlers must call controller.addError so subscribers '
            'see the failure',
      );
    });
  });
}
