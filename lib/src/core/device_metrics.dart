import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../models/log_models.dart';

class DeviceVitalsCollector {
  DeviceVitalsCollector({
    this.runtimeProbe,
    this.collectExtendedDetails = true,
  });

  static const MethodChannel _channel = MethodChannel('scout_logger/system');
  final Future<Map<String, dynamic>> Function()? runtimeProbe;
  final bool collectExtendedDetails;
  final Battery _battery = Battery();

  Future<DeviceVitalsSnapshot> collectAtCrashTime() async {
    final DeviceInfoPlugin infoPlugin = DeviceInfoPlugin();
    String os = Platform.operatingSystemVersion;
    String model = 'unknown';
    String maker = 'unknown';
    final Map<String, dynamic> extended = <String, dynamic>{
      'platform': Platform.operatingSystem,
    };

    if (Platform.isAndroid) {
      final AndroidDeviceInfo info = await infoPlugin.androidInfo;
      os = info.version.release;
      model = info.model;
      maker = info.manufacturer;
      if (collectExtendedDetails) {
        extended.addAll(<String, dynamic>{
          'androidSdkInt': info.version.sdkInt,
          'brand': info.brand,
          'device': info.device,
          'isPhysicalDevice': info.isPhysicalDevice,
          'supportedAbis': info.supportedAbis,
        });
      }
    } else if (Platform.isIOS) {
      final IosDeviceInfo info = await infoPlugin.iosInfo;
      os = info.systemVersion;
      model = info.utsname.machine;
      maker = 'Apple';
      if (collectExtendedDetails) {
        extended.addAll(<String, dynamic>{
          'systemName': info.systemName,
          'isPhysicalDevice': info.isPhysicalDevice,
          'identifierForVendor': info.identifierForVendor,
        });
      }
    }

    final Map<Object?, Object?> batteryRaw =
        await _readMap('battery') ?? const <Object?, Object?>{};
    final Map<Object?, Object?> thermalRaw =
        await _readMap('thermal') ?? const <Object?, Object?>{};
    final Map<String, dynamic> runtime = await _readRuntimeProbe();
    final int usedRam = ProcessInfo.currentRss;
    final int? freeRamBytes =
        _asInt(batteryRaw['freeRamBytes']) ?? _asInt(runtime['freeRamBytes']);

    double? batteryLevel =
        _asDouble(batteryRaw['batteryLevel']) ?? _asDouble(runtime['batteryLevel']);
    String? chargingState = _asString(batteryRaw['chargingState']) ??
        _asString(runtime['chargingState']);
    String? thermalState =
        _asString(thermalRaw['thermalState']) ?? _asString(runtime['thermalState']);

    if (collectExtendedDetails) {
      try {
        batteryLevel ??= await _battery.batteryLevel / 100.0;
        final BatteryState state = await _battery.batteryState;
        chargingState ??= state.name;
        extended['batteryState'] = state.name;
      } catch (_) {
        // battery_plus may be unavailable on some platforms (e.g. web).
      }
    }

    return DeviceVitalsSnapshot(
      osVersion: os,
      deviceModel: model,
      manufacturer: maker,
      ramUsedBytes: usedRam,
      ramFreeBytes: freeRamBytes,
      batteryLevel: batteryLevel,
      chargingState: chargingState,
      thermalState: thermalState,
      extendedDetails: extended,
    );
  }

  Future<Map<Object?, Object?>?> _readMap(String method) async {
    try {
      final dynamic result = await _channel.invokeMethod<dynamic>(method);
      if (result is Map) {
        return result;
      }
    } catch (_) {
      //
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
