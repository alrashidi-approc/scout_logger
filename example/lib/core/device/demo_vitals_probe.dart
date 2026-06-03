import 'dart:io';

import 'package:battery_plus/battery_plus.dart';

/// Real device vitals for the demo (host app responsibility in production).
Future<Map<String, dynamic>> collectDemoRuntimeVitals() async {
  final Map<String, dynamic> vitals = <String, dynamic>{
    'thermalState': 'nominal',
  };

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final Battery battery = Battery();
      final int percent = await battery.batteryLevel;
      vitals['batteryLevel'] = percent / 100.0;
      vitals['chargingState'] = (await battery.batteryState).name;
    } catch (_) {
      vitals['chargingState'] = 'unavailable';
    }
  } else {
    vitals['chargingState'] = 'n/a';
  }

  vitals['freeRamBytes'] = _estimateFreeRamBytes();
  return vitals;
}

int? _estimateFreeRamBytes() {
  try {
    final int used = ProcessInfo.currentRss;
    // Demo-only hint when OS free RAM is not exposed without a native channel.
    const int assumedTotal = 4 * 1024 * 1024 * 1024;
    final int free = assumedTotal - used;
    return free > 0 ? free : null;
  } catch (_) {
    return null;
  }
}
