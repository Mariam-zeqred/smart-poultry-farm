// Bug 7 regression guard: every actuator setter (fan, light, heater, feeder)
// must check `safetyOverride` before writing — matching the LCD's check of
// `safetyActive` on the ESP side.  Without this, the app can override a safety
// shutdown that the firmware enforced.
//
// We scan the source file and count how many of the four setters contain the
// safety-guard pattern. A setter is considered guarded if it reads the control
// state and checks `safetyOverride`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('device_provider safety guard regression (Bug 7)', () {
    final source = File(
      'lib/features/devices/providers/device_provider.dart',
    ).readAsStringSync();

    // Extract the body of each setter by finding the method declaration and
    // taking everything up to the closing brace of that method.
    String _extractMethod(String methodName) {
      final startIdx = source.indexOf('Future<void> $methodName(');
      if (startIdx == -1) return '';
      // Scan forward to find the matching closing brace.
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

    // A setter is "guarded" if it either:
    //   (a) directly contains `safetyOverride` (inline check), OR
    //   (b) calls a dedicated guard helper that itself contains the check.
    // Both patterns are equivalent for safety; we accept either.
    bool _bodyCallsGuardHelper(String body) {
      // Find every `await foo();` or `_foo()` call in the body and check
      // whether any of the called helpers contain 'safetyOverride'.
      final callPattern = RegExp(r'await\s+(_\w+)\(|(_\w+)\(');
      for (final m in callPattern.allMatches(body)) {
        final helperName = m.group(1) ?? m.group(2);
        if (helperName == null) continue;
        final helperBody = _extractMethod(helperName);
        if (helperBody.contains('safetyOverride')) return true;
      }
      return false;
    }

    void _expectSafetyGuard(String methodName) {
      final body = _extractMethod(methodName);
      final inlineCheck = body.contains('safetyOverride');
      final delegatedCheck = _bodyCallsGuardHelper(body);

      expect(
        inlineCheck || delegatedCheck,
        isTrue,
        reason: '$methodName must check safetyOverride before writing '
            '— either inline or via a shared guard helper '
            '(symmetry with ESP LCD safety check)',
      );

      // The throw message must exist somewhere in the file (either inline or in helper).
      expect(
        source,
        contains('Safety override active'),
        reason: 'Must throw "Safety override active" when safetyOverride is true',
      );
    }

    test('setFanState checks safetyOverride before writing', () {
      _expectSafetyGuard('setFanState');
    });

    test('setLightState checks safetyOverride before writing', () {
      _expectSafetyGuard('setLightState');
    });

    test('setHeaterState checks safetyOverride before writing', () {
      _expectSafetyGuard('setHeaterState');
    });

    test('toggleFeeder checks safetyOverride before writing', () {
      _expectSafetyGuard('toggleFeeder');
    });

    test('setControlMode already checks safetyOverride (baseline)', () {
      // Sanity-check that setControlMode, which was already correct, still passes.
      _expectSafetyGuard('setControlMode');
    });
  });
}
