import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/core/device_metrics.dart';

void main() {
  test('uses runtime probe values when channel values are absent', () async {
    final DeviceVitalsCollector collector = DeviceVitalsCollector(
      runtimeProbe: () async => <String, dynamic>{
        'batteryLevel': 87.5,
        'chargingState': 'charging',
        'thermalState': 'nominal',
        'freeRamBytes': 2048,
      },
    );

    final snapshot = await collector.collectAtCrashTime();
    expect(snapshot.batteryLevel, 87.5);
    expect(snapshot.chargingState, 'charging');
    expect(snapshot.thermalState, 'nominal');
    expect(snapshot.ramFreeBytes, 2048);
  });
}
