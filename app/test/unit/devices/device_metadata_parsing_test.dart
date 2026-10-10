// Bug 4 regression guard: Firebase RTDB returns integer fields as `double`
// when the value was originally written from certain paths (the SDK does not
// preserve the int/double distinction across writes from JS / cloud functions).
// `DeviceMetadata.fromMap` must accept either form without throwing.
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_poultry_farm/core/models/device_model.dart';

void main() {
  group('DeviceMetadata.fromMap int/double coercion', () {
    test('lastSeen and startupTime accept double silently (regression)', () {
      final meta = DeviceMetadata.fromMap({
        'lastSeen': 1700000000000.0,
        'startupTime': 1699999999000.0,
      });
      expect(meta.lastSeen, 1700000000000);
      expect(meta.startupTime, 1699999999000);
    });
  });
}
