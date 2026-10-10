// Bug 5 regression guard: ESP firebaseTask must use RTDB SSE streaming,
// not REST polling, for control/state and config/thresholds changes.
//
// These source-scan tests are the only practical automated gate for C++ firmware
// because the Arduino/ESP32 toolchain has no CI-runnable test harness in this
// project. The scans enforce that the key structural guarantees exist.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ESP firmware streaming (Bug 5)', () {
    final ino = File(
      '../esp32_firmware_arduino/esp32_firmware_arduino.ino',
    ).readAsStringSync();

    final streamH = File(
      '../esp32_firmware_arduino/firebase_stream.h',
    ).readAsStringSync();

    final streamCpp = File(
      '../esp32_firmware_arduino/firebase_stream.cpp',
    ).readAsStringSync();

    // ---- USE_STREAMING flag ----

    test('USE_STREAMING is defined and enabled', () {
      // If this flag is 0 the ESP falls back to polling and all streaming
      // latency benefits are lost.
      expect(ino, contains('#define USE_STREAMING 1'));
    });

    // ---- SSE client header API ----

    test('firebase_stream.h declares firebase_stream_begin', () {
      expect(streamH, contains('firebase_stream_begin'));
    });

    test('firebase_stream.h declares firebase_stream_loop', () {
      expect(streamH, contains('firebase_stream_loop'));
    });

    test('firebase_stream.h declares FirebaseStreamCallback typedef', () {
      expect(streamH, contains('FirebaseStreamCallback'));
    });

    // ---- SSE client implementation correctness ----

    test('firebase_stream_loop is non-blocking (uses available(), not readStringUntil)', () {
      // Extract only the firebase_stream_loop function body to verify that the
      // loop itself never blocks. readStringUntil is acceptable in
      // firebase_stream_begin() for the one-shot HTTP handshake, but must not
      // appear inside the recurring loop.
      final loopStart = streamCpp.indexOf('bool firebase_stream_loop()');
      final loopEnd   = streamCpp.indexOf('\nbool ', loopStart + 1);
      final loopBody  = loopEnd > loopStart
          ? streamCpp.substring(loopStart, loopEnd)
          : streamCpp.substring(loopStart);

      expect(loopBody, contains('available()'),
          reason: 'firebase_stream_loop must call available() to avoid blocking');
      expect(
        loopBody,
        isNot(contains('readStringUntil')),
        reason: 'readStringUntil blocks — must not be used inside firebase_stream_loop',
      );
    });

    test('firebase_stream.cpp handles keep-alive without callback', () {
      // Keep-alive events must be swallowed silently; invoking the callback
      // on them would cause spurious state updates.
      expect(streamCpp, contains('"keep-alive"'));
    });

    test('firebase_stream.cpp has idle timeout guard', () {
      // Without a timeout the dead-connection case is never detected.
      expect(streamCpp, contains('STREAM_IDLE_TIMEOUT_MS'));
    });

    // ---- .ino wires streaming correctly ----

    test('firebaseTask calls firebase_stream_loop in streaming path', () {
      expect(ino, contains('firebase_stream_loop()'));
    });

    test('streamSubscribe() opens the connection with onStreamEvent callback', () {
      expect(ino, contains('streamSubscribe'));
      expect(ino, contains('onStreamEvent'));
      expect(ino, contains('firebase_stream_begin'));
    });

    test('REST polling is gated behind !USE_STREAMING preprocessor guard', () {
      // Sensor push and heartbeat are outside the guard (always run).
      // Control/state and threshold REST reads must only run when streaming is off.
      expect(ino, contains('#if !USE_STREAMING'));
      // The streaming drain must be in the #else branch.
      expect(ino, contains('#else'));
    });

    test('onStreamEvent handles /control/state path', () {
      expect(ino, contains('"/control/state"'));
    });

    test('onStreamEvent handles /config/thresholds path', () {
      expect(ino, contains('"/config/thresholds"'));
    });

    test('onStreamEvent handles root path for initial snapshot hydration', () {
      // Firebase RTDB sends a full snapshot on first subscription with path="/".
      // Without handling it, the ESP misses the initial state on connect.
      expect(
        ino,
        contains('"/"'),
        reason: 'onStreamEvent must handle path="/" for initial put snapshot',
      );
    });
  });
}
