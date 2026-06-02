import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../models/log_models.dart';

class DeviceVitalsCollector {
  DeviceVitalsCollector({this.runtimeProbe});

  static const MethodChannel _channel = MethodChannel('scout_logger/system');
  final Future<Map<String, dynamic>> Function()? runtimeProbe;

  Future<DeviceVitalsSnapshot> collectAtCrashTime() async {
    final DeviceInfoPlugin infoPlugin = DeviceInfoPlugin();
    String os = Platform.operatingSystemVersion;
    String model = 'unknown';
    String maker = 'unknown';

    if (Platform.isAndroid) {
      final AndroidDeviceInfo info = await infoPlugin.androidInfo;
      os = info.version.release;
      model = info.model;
      maker = info.manufacturer;
    } else if (Platform.isIOS) {
      final IosDeviceInfo info = await infoPlugin.iosInfo;
      os = info.systemVersion;
      model = info.utsname.machine;
      maker = 'Apple';
    }

    final Map<Object?, Object?> batteryRaw =
        await _readMap('battery') ?? const <Object?, Object?>{};
    final Map<Object?, Object?> thermalRaw =
        await _readMap('thermal') ?? const <Object?, Object?>{};
    final Map<String, dynamic> runtime = await _readRuntimeProbe();
    final int usedRam = ProcessInfo.currentRss;
    final int? freeRamBytes =
        _asInt(batteryRaw['freeRamBytes']) ?? _asInt(runtime['freeRamBytes']);
    final double? batteryLevel =
        _asDouble(batteryRaw['batteryLevel']) ?? _asDouble(runtime['batteryLevel']);
    final String? chargingState = _asString(batteryRaw['chargingState']) ??
        _asString(runtime['chargingState']);
    final String? thermalState =
        _asString(thermalRaw['thermalState']) ?? _asString(runtime['thermalState']);

    return DeviceVitalsSnapshot(
      osVersion: os,
      deviceModel: model,
      manufacturer: maker,
      ramUsedBytes: usedRam,
      ramFreeBytes: freeRamBytes,
      batteryLevel: batteryLevel,
      chargingState: chargingState,
      thermalState: thermalState,
    );
  }

  Future<Map<Object?, Object?>?> _readMap(String method) async {
    try {
      final dynamic result = await _channel.invokeMethod<dynamic>(method);
      if (result is Map) {
        return result;
      }
    } catch (_) {
      // Missing platform implementation is accepted for package consumers.
    }
    return null;
  }

  Future<Map<String, dynamic>> _readRuntimeProbe() async {
    final Future<Map<String, dynamic>> Function()? probe = runtimeProbe;
    if (probe == null) {
      return const <String, dynamic>{};
    }
    try {
      return await probe();
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  int? _asInt(Object? value) => value is num ? value.toInt() : null;

  double? _asDouble(Object? value) => value is num ? value.toDouble() : null;

  String? _asString(Object? value) => value?.toString();
}
