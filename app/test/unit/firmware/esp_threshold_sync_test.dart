// Bug 6 firmware regression guard: when the cloud delivers newer threshold
// values (stamped with lastModifiedAt by the app), the ESP must discard any
// pending LCD edits rather than flushing them back over the app's write.
//
// The mechanism: thresholdsDirty is cleared whenever cloud values are applied
// via streaming, initial hydration, or REST poll. This prevents the race where:
//   1. App writes thresholds with lastModifiedAt=T1
//   2. ESP (offline) changes thresholds via LCD -> thresholdsDirty=true
//   3. ESP reconnects, receives cloud values (T1)
//   4. WITHOUT fix: ESP flushes dirty values, overwrites app's T1
//   5. WITH fix:    thresholdsDirty=false on receive; flush is skipped
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ESP threshold last-writer-wins (Bug 6 firmware side)', () {
    final ino = File(
      '../esp32_firmware_arduino/esp32_firmware_arduino.ino',
    ).readAsStringSync();

    // Helper: extract a named section between two markers for focused matching.
    // We search for the FIRST occurrence of startMarker and scan forward to
    // the FIRST occurrence of endMarker that follows it.
    String _section(String startMarker, String endMarker) {
      final start = ino.indexOf(startMarker);
      if (start == -1) return '';
      final end = ino.indexOf(endMarker, start);
      return end == -1 ? ino.substring(start) : ino.substring(start, end);
    }

    test('app threshold write includes lastModifiedAt in Flutter provider', () {
      // Cross-check: the app-side fix (Bug 6 Flutter) must also be present so
      // the cloud node actually carries the timestamp the firmware trusts.
      final providerSource = File(
        'lib/features/devices/providers/device_provider.dart',
      ).readAsStringSync();
      expect(
        providerSource,
        contains("'lastModifiedAt'"),
        reason: 'updateThresholds must write lastModifiedAt: ServerValue.timestamp',
      );
    });

    test('streaming callback clears thresholdsDirty when cloud thresholds arrive', () {
      // Locate the threshold-change block inside onStreamEvent and verify
      // thresholdsDirty is cleared after applyThresholdsDoc succeeds.
      final streamSection = _section(
        '// ---- Threshold changes ----',
        '// ---- Manual priority timeout',
      );
      expect(
        streamSection,
        contains('thresholdsDirty = false'),
        reason: 'onStreamEvent must clear thresholdsDirty so pending LCD edits '
            'do not overwrite a newer app write',
      );
    });

    test('initial root hydration clears thresholdsDirty after applying cloud thresholds', () {
      // When ESP first connects, Firebase sends a full put at path="/".
      // That handler must also clear thresholdsDirty.
      final rootSection = _section(
        'Initial subscription event: path="/"',
        '} // onStreamEvent',
      );
      expect(
        rootSection,
        contains('thresholdsDirty = false'),
        reason: 'Root hydration handler must clear thresholdsDirty; otherwise '
            'LCD edits made while offline overwrite the initial cloud snapshot',
      );
    });

    test('REST polling path clears thresholdsDirty when cloud values are applied', () {
      // In REST fallback mode the same guarantee must hold.
      final restSection = _section(
        '// ---- 3. Poll thresholds',
        '// ---- 4. Auto-control',
      );
      expect(
        restSection,
        contains('thresholdsDirty = false'),
        reason: 'REST poll must clear thresholdsDirty after applying cloud values',
      );
    });

    test('thresholdsDirty flush is still attempted before the cloud read', () {
      // We must flush LCD edits to cloud BEFORE reading cloud values so we
      // don't silently overwrite a locally-dirty state.
      // The flush block ("---- 0.") must appear before the poll block ("---- 3.").
      final flushIdx    = ino.indexOf('// ---- 0. Flush local threshold');
      final pollIdx     = ino.indexOf('// ---- 3. Poll thresholds');
      final streamIdx   = ino.indexOf('// ---- 2+3. Drain RTDB stream');

      expect(flushIdx, isNot(-1), reason: 'Flush block (step 0) must exist');
      // Either REST poll or streaming drain must come after the flush.
      final drainIdx = pollIdx != -1 ? pollIdx : streamIdx;
      expect(drainIdx, isNot(-1), reason: 'Threshold read block must exist');
      expect(
        flushIdx < drainIdx,
        isTrue,
        reason: 'Threshold flush (step 0) must execute before cloud read (step 3)',
      );
    });
  });
}
