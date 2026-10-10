/// Device repository + providers: the single stream every dashboard widget
/// watches, and every write the app makes to the controller.
///
/// Responsibilities:
///   * Combine `sensors/latest`, `control/state`, `meta` and `config/fanCycle`
///     into one [DeviceSnapshot], including the derived "is online" flag
///     (based on `meta.lastSeen` age).
///   * Write control commands (`setFanState`, `setControlMode`, App Control
///     toggle, thresholds, fan cycle) with the same client-side guards the
///     firmware enforces server-side: no actuator writes while Auto or while
///     a safety override is active, no fan writes while a fan cycle owns it.
///   * Append each new `sensors/latest` reading to `sensors/history` — the
///     ESP32 never writes history itself; this app is the historian.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/models/sensor_model.dart';
import '../../../core/models/device_model.dart';
import '../../../core/providers/firebase_providers.dart';
import 'sensor_history_provider.dart';

final deviceRepoProvider = Provider<DeviceRepository>((ref) {
  final database = ref.watch(databaseProvider);
  final historyRepo = ref.watch(sensorHistoryRepoProvider);
  return DeviceRepository(database, historyRepo);
});

class DeviceSnapshot {
  final SensorLatest latest;
  final ControlState state;
  final String deviceId;
  final bool isOnline;
  final DeviceMetadata? metadata;
  final FanCycleConfig fanCycle;

  const DeviceSnapshot({
    required this.latest,
    required this.state,
    required this.deviceId,
    required this.isOnline,
    this.metadata,
    this.fanCycle = FanCycleConfig.defaults,
  });
}

/// Single-ESP repository. All data lives under the flat `/farm/` node.
class DeviceRepository {
  final DatabaseReference _database;
  final SensorHistoryRepository _historyRepo;

  DeviceRepository(this._database, this._historyRepo);

  // Single farm node — no device-id, no multi-device complexity.
  static const String _farmPath = 'farm';
  static const String _deviceId = 'esp32_device'; // used only for display
  // Freshness window is owned by DeviceMetadata so the repository's
  // `DeviceSnapshot.isOnline` and the metadata getter cannot drift apart.

  DatabaseReference get _farm => _database.child(_farmPath);

  Future<void> _ensureRealtimeConnected() async {
    try {
      // Right after the SDK initializes, `.info/connected` briefly reports
      // false while the websocket handshake completes — a single once()
      // read can race that and see the stale false. Wait for a true event
      // instead of trusting the first snapshot.
      final connected = await _database
          .child('.info/connected')
          .onValue
          .map((e) => e.snapshot.value == true)
          .firstWhere((v) => v, orElse: () => false)
          .timeout(const Duration(seconds: 5));
      if (!connected) {
        throw Exception('Phone is offline. Please reconnect internet first.');
      }
    } catch (_) {
      throw Exception('No Firebase connection. Try again when online.');
    }
  }

  Stream<DeviceSnapshot> watchDevice() async* {
    try {
      await _ensureRealtimeConnected();

      // Check ESP has ever reported in
      final metaSnap = await _farm
          .child('meta')
          .once()
          .timeout(const Duration(seconds: 6));
      if (!metaSnap.snapshot.exists) {
        yield* Stream.error('No device found');
        return;
      }

      final metaMap = metaSnap.snapshot.value is Map
          ? Map<String, dynamic>.from(metaSnap.snapshot.value as Map)
          : <String, dynamic>{};
      final lastSeen = (metaMap['lastSeen'] as num?)?.toInt() ?? 0;

      if (lastSeen == 0) {
        final sensorSnap = await _farm
            .child('sensors/latest/ts')
            .once()
            .timeout(const Duration(seconds: 6));
        final sensorTs = (sensorSnap.snapshot.value as num?)?.toInt() ?? 0;
        if (sensorTs == 0) {
          yield* Stream.error('Device provisioned but not yet connected');
          return;
        }
      }

      yield* _combineDeviceStreams(
        _farm.child('sensors/latest').onValue,
        _farm.child('control/state').onValue,
        _farm.child('meta').onValue,
        _farm.child('config/thresholds').onValue,
        _farm.child('config/fanCycle').onValue,
      );
    } on TimeoutException {
      yield* Stream.error(
          'Timed out reaching Firebase. Check internet and try again.');
    } catch (_) {
      yield* Stream.error('Cannot reach Firebase right now.');
    }
  }

  Stream<DeviceSnapshot> _combineDeviceStreams(
    Stream<DatabaseEvent> sensorsStream,
    Stream<DatabaseEvent> controlStream,
    Stream<DatabaseEvent> metaStream,
    Stream<DatabaseEvent> thresholdsStream,
    Stream<DatabaseEvent> fanCycleStream,
  ) {
    final controller = StreamController<DeviceSnapshot>();

    SensorLatest cachedSensors =
        SensorLatest(temperature: 0, humidity: 0, gas: 0, ts: 0);
    ControlState cachedControl = ControlState(
      fanState: false,
      coolerState: false,
      heaterState: false,
      humidifierState: false,
      controlMode: 'manual',
    );
    Map<String, dynamic>? cachedMetaMap;
    Map<String, dynamic>? cachedThresholdsMap;
    DeviceMetadata? cachedMetadata;
    FanCycleConfig cachedFanCycle = FanCycleConfig.defaults;

    void rebuildMetadata() {
      if (cachedMetaMap != null) {
        final combined = Map<String, dynamic>.from(cachedMetaMap!);
        if (cachedThresholdsMap != null) {
          combined['thresholds'] = cachedThresholdsMap;
        }
        cachedMetadata = DeviceMetadata.fromMap(combined);
      }
    }

    void emit() {
      if (controller.isClosed) return;
      final lastSeen = cachedMetadata?.lastSeen ?? 0;
      final sensorTs = cachedSensors.ts;
      final heartbeatTs = sensorTs > lastSeen ? sensorTs : lastSeen;
      final isOnline = heartbeatTs > 0 &&
          (DateTime.now().millisecondsSinceEpoch - heartbeatTs <
              DeviceMetadata.onlineWindowMs);

      controller.add(DeviceSnapshot(
        latest: cachedSensors,
        state: cachedControl,
        deviceId: _deviceId,
        isOnline: isOnline,
        metadata: cachedMetadata,
        fanCycle: cachedFanCycle,
      ));
    }

    // Forward Firebase stream errors (auth expiry, permission denied,
    // transient network) to the merged controller so subscribers see the
    // failure instead of being stuck on stale data forever.
    void forwardError(Object error, StackTrace stack) {
      if (controller.isClosed) return;
      controller.addError(error, stack);
    }

    final sub1 = sensorsStream.listen((event) {
      if (event.snapshot.value != null) {
        final map =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        cachedSensors = SensorLatest.fromMap(map);
        _historyRepo.storeSensorReading(cachedSensors).catchError((Object e) {
          debugPrint('Failed to store sensor history: $e');
        });
      }
      emit();
    }, onError: forwardError);

    final sub2 = controlStream.listen((event) {
      if (event.snapshot.value != null) {
        final map =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        cachedControl = ControlState.fromMap(map);
      }
      emit();
    }, onError: forwardError);

    final sub3 = metaStream.listen((event) {
      if (event.snapshot.value != null) {
        cachedMetaMap =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        rebuildMetadata();
      }
      emit();
    }, onError: forwardError);

    final sub4 = thresholdsStream.listen((event) {
      if (event.snapshot.value != null) {
        cachedThresholdsMap =
            Map<String, dynamic>.from(event.snapshot.value as Map);
        rebuildMetadata();
      }
      emit();
    }, onError: forwardError);

    final sub5 = fanCycleStream.listen((event) {
      cachedFanCycle = FanCycleConfig.fromMap(
        event.snapshot.value is Map
            ? Map<String, dynamic>.from(event.snapshot.value as Map)
            : null,
      );
      emit();
    }, onError: forwardError);

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
      sub4.cancel();
      sub5.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Future<void> _guardSafety() async {
    final snapshot = await _farm.child('control/state').get();
    final safetyOverride =
        snapshot.child('safetyOverride').value as bool? ?? false;
    if (safetyOverride) {
      throw Exception(
          'Safety override active — cannot change actuators until sensors return to safe levels');
    }
  }

  /// Throws if the device is currently in Auto mode — actuators are only
  /// settable in Manual mode now (HW team, 2026-08-29: Auto and Manual are
  /// mutually exclusive control regimes, not "auto with a temporary manual
  /// override window" — toggling an actuator while Auto used to silently
  /// start a temporary override that auto-control would then fight over a
  /// few seconds later, which looked like actuators misbehaving). The
  /// firmware enforces this too (applyControlStateDoc() ignores actuator
  /// fields while Auto) — this just gives an immediate, clear error
  /// instead of a silently-ignored write.
  Future<void> _guardAutoMode() async {
    final snapshot = await _farm.child('control/state/controlMode').get();
    if (snapshot.value == 'automatic') {
      throw Exception(
          'Switch to Manual mode first to control actuators directly');
    }
  }

  /// Throws if the LCD currently owns control ownership (2026-08-29) — the
  /// app's Farm Control section is monitor-only in that case, mirroring
  /// the firmware's own guard in applyControlStateDoc() (only honors
  /// mode/actuator writes while appControlEnabled is true). Only the app
  /// can flip control ownership itself — see setAppControlEnabled(), the
  /// one write that's never guarded by this check.
  Future<void> _guardAppControl() async {
    final snapshot =
        await _farm.child('control/state/appControlEnabled').get();
    // Missing field (older/never-touched device) defaults to app-owned,
    // mirroring the firmware's own default — matches pre-feature behavior.
    final appOwnsControl = snapshot.value == null ? true : snapshot.value as bool;
    if (!appOwnsControl) {
      throw Exception(
          'The device LCD currently owns control — turn App Control back on to command actuators from here');
    }
  }

  /// Throws if the fan is currently under scheduled-cycle control — the
  /// cycle owns the fan exclusively while active (mirrors the firmware's
  /// own guard in onUiToggle()/handleControlButtons()).
  Future<void> _guardFanCycle() async {
    final snapshot = await _farm.child('config/fanCycle/enabled').get();
    final cycleEnabled = snapshot.value as bool? ?? false;
    if (cycleEnabled) {
      throw Exception(
          'Fan is on a scheduled cycle — disable the cycle first to control it manually');
    }
  }

  Future<void> setFanState(bool on) async {
    await _ensureRealtimeConnected();
    await _guardSafety();
    await _guardAppControl();
    await _guardAutoMode();
    await _guardFanCycle();
    await _farm.child('control/state').update({
      'fanState': on,
      'reason': 'User command (app)',
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<void> setCoolerState(bool on) async {
    await _ensureRealtimeConnected();
    await _guardSafety();
    await _guardAppControl();
    await _guardAutoMode();
    await _farm.child('control/state').update({
      'coolerState': on,
      'reason': 'User command (app)',
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<void> setHeaterState(bool on) async {
    await _ensureRealtimeConnected();
    await _guardSafety();
    await _guardAppControl();
    await _guardAutoMode();
    await _farm.child('control/state').update({
      'heaterState': on,
      'reason': 'User command (app)',
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<void> setHumidifierState(bool on) async {
    await _ensureRealtimeConnected();
    await _guardSafety();
    await _guardAppControl();
    await _guardAutoMode();
    await _farm.child('control/state').update({
      'humidifierState': on,
      'reason': 'User command (app)',
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<void> setControlMode(String mode) async {
    await _ensureRealtimeConnected();
    await _guardSafety();
    await _guardAppControl();
    await _farm.child('control/state').update({
      'controlMode': mode,
      'reason': mode == 'automatic'
          ? 'Auto-control enabled by user'
          : 'Manual control enabled by user',
      'updated_at': ServerValue.timestamp,
    });
  }

  /// Hands control ownership between the app and the device LCD (2026-08-29).
  /// Deliberately NOT guarded by _guardAppControl() — this is the one write
  /// that must always be allowed regardless of who currently owns control,
  /// since it's the only way to take control back from the app side (the
  /// LCD has no UI for this field at all, by design). The firmware always
  /// honors it unconditionally too — see applyControlStateDoc()'s comment.
  Future<void> setAppControlEnabled(bool enabled) async {
    await _ensureRealtimeConnected();
    await _guardSafety();
    await _farm.child('control/state').update({
      'appControlEnabled': enabled,
      'reason': enabled
          ? 'App control enabled by user'
          : 'Control handed to device LCD by user',
      'updated_at': ServerValue.timestamp,
    });
  }

  Future<SensorThresholds?> getThresholds() async {
    final snapshot = await _farm.child('config/thresholds').get();
    if (snapshot.value == null) return null;
    return SensorThresholds.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map));
  }

  Future<void> updateThresholds({
    required double temperatureHigh,
    required double temperatureLow,
    required double humidityHigh,
    required double humidityLow,
    required double gasHigh,
    double? hysteresis,
  }) async {
    await _ensureRealtimeConnected();

    final thresholds = SensorThresholds(
      temperatureHigh: temperatureHigh,
      temperatureLow: temperatureLow,
      humidityHigh: humidityHigh,
      humidityLow: humidityLow,
      gasHigh: gasHigh,
      hysteresis: hysteresis ?? SensorThresholds.defaultHysteresis,
    );

    final error = thresholds.validate();
    if (error != null) throw Exception('Invalid thresholds: ${error.name}');

    await _farm.child('config/thresholds').update({
      ...thresholds.toMap(),
      'lastModifiedAt': ServerValue.timestamp,
    });
  }

  Future<FanCycleConfig?> getFanCycle() async {
    final snapshot = await _farm.child('config/fanCycle').get();
    if (snapshot.value == null) return null;
    return FanCycleConfig.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map));
  }

  /// Set the scheduled fan-airing cycle. While [enabled], the firmware
  /// drives the Fan exclusively on this ON/OFF schedule, independent of
  /// gas/temp/humidity — manual fan control is locked until disabled.
  Future<void> updateFanCycle(FanCycleConfig cycle) async {
    await _ensureRealtimeConnected();
    await _farm.child('config/fanCycle').update(cycle.toMap());
  }
}

final deviceProvider =
    StreamProvider.autoDispose<DeviceSnapshot>((ref) {
  ref.keepAlive();
  return ref.watch(deviceRepoProvider).watchDevice();
});
