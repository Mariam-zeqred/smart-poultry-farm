// Bug 3 regression guard: a device is "online" only if its last heartbeat
// is within the freshness window. The DeviceRepository uses 45 seconds for
// `DeviceSnapshot.isOnline`, but `DeviceMetadata.isOnline` historically used
// 5 minutes — so any UI that read `snapshot.metadata?.isOnline` showed the
// device as online for >4 minutes after it had actually gone offline.
//
// Both code paths must agree. We pin the shared window to 45_000 ms.
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_poultry_farm/core/models/device_model.dart';

void main() {
  group('DeviceMetadata.isOnline freshness window', () {
    test('window constant is 45_000 ms (matches DeviceRepository)', () {
      expect(DeviceMetadata.onlineWindowMs, 45000);
    });

    test('returns true for fresh heartbeat (5s ago)', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final meta = DeviceMetadata.fromMap({'lastSeen': now - 5000});
      expect(meta.isOnline, isTrue);
    });

    test('returns false for stale heartbeat (60s ago) — was true with 5min window', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final meta = DeviceMetadata.fromMap({'lastSeen': now - 60000});
      expect(meta.isOnline, isFalse,
          reason: 'Device 60s stale must NOT be reported online');
    });

    test('returns false for never-seen device (lastSeen = 0)', () {
      final meta = DeviceMetadata.fromMap({'lastSeen': 0});
      expect(meta.isOnline, isFalse);
    });
  });
}
