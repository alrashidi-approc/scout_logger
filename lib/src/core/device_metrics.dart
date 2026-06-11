import 'dart:io';

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

  Future<DeviceVitalsSnapshot> collectAtCrashTime() async {
    final DeviceInfoPlugin infoPlugin = DeviceInfoPlugin();
    String os = Platform.operatingSystemVersion;
    String model = 'unknown';
    String maker = 'unknown';
    String? deviceName;
    String? localizedModel;
    final Map<String, dynamic> extended = <String, dynamic>{
      'platform': Platform.operatingSystem,
    };

    if (Platform.isAndroid) {
      final AndroidDeviceInfo info = await infoPlugin.androidInfo;
      os = info.version.release;
      model = info.model;
      maker = info.manufacturer;
      localizedModel = info.model.trim().isEmpty ? null : info.model;
      final String label = '${info.brand} ${info.model}'.trim();
      deviceName = label.isEmpty ? null : label;
      if (collectExtendedDetails) {
        extended.addAll(<String, dynamic>{
          'androidSdkInt': info.version.sdkInt,
          'brand': info.brand,
          'device': info.device,
          'product': info.product,
          'isPhysicalDevice': info.isPhysicalDevice,
          'supportedAbis': info.supportedAbis,
        });
      }
    } else if (Platform.isIOS) {
      final IosDeviceInfo info = await infoPlugin.iosInfo;
      os = info.systemVersion;
      model = info.utsname.machine;
      maker = 'Apple';
      final String name = info.name.trim();
      deviceName = name.isEmpty ? null : name;
      final String localized = info.localizedModel.trim();
      localizedModel = localized.isEmpty ? null : localized;
      if (collectExtendedDetails) {
        extended.addAll(<String, dynamic>{
          'systemName': info.systemName,
          'isPhysicalDevice': info.isPhysicalDevice,
          'identifierForVendor': info.identifierForVendor,
        });
      }
    }

    final Map<String, dynamic> runtime = await _readRuntimeProbe();
    deviceName ??= _asString(runtime['deviceName']);
    localizedModel ??= _asString(runtime['localizedModel']);

    final Map<Object?, Object?> batteryRaw =
        await _readMap('battery') ?? const <Object?, Object?>{};
    final Map<Object?, Object?> thermalRaw =
        await _readMap('thermal') ?? const <Object?, Object?>{};
    final int usedRam = ProcessInfo.currentRss;
    final int? freeRamBytes =
        _asInt(batteryRaw['freeRamBytes']) ?? _asInt(runtime['freeRamBytes']);

    double? batteryLevel =
        _asDouble(batteryRaw['batteryLevel']) ?? _asDouble(runtime['batteryLevel']);
    String? chargingState = _asString(batteryRaw['chargingState']) ??
        _asString(runtime['chargingState']);
    String? thermalState =
        _asString(thermalRaw['thermalState']) ?? _asString(runtime['thermalState']);

    return DeviceVitalsSnapshot(
      osVersion: os,
      deviceModel: model,
      manufacturer: maker,
      deviceName: deviceName,
      localizedModel: localizedModel,
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
