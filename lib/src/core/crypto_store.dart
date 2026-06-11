import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import '../models/log_models.dart';

class EncryptedLogStore {
  EncryptedLogStore(this._encryptionKey, {String? storagePath})
    : _storagePathOverride = storagePath;

  final String _encryptionKey;
  final String? _storagePathOverride;
  final AesGcm _aes = AesGcm.with256bits();
  Future<void> _ops = Future<void>.value();

  String get _storagePath =>
      _storagePathOverride ?? '${Directory.systemTemp.path}/scout_logger_store.enc';

  Future<void> insert(LogEnvelope log) {
    return _locked(() async {
      final List<String> lines = await _readAllLines();
      lines.add(await _encrypt(log.toCompactJson()));
      await _atomicWriteLines(lines);
    });
  }

  Future<List<LogEnvelope>> readBatch({required int maxItems}) {
    return _locked(() async {
      final List<String> lines = await _readAllLines();
      final List<LogEnvelope> logs = <LogEnvelope>[];
      for (final String line in lines.take(maxItems)) {
        final String? clear = await _tryDecrypt(line);
        if (clear == null) {
          continue;
        }
        final Map<String, dynamic> json = jsonDecode(clear) as Map<String, dynamic>;
        logs.add(_fromJson(json));
      }
      return logs;
    });
  }

  Future<void> removeFirst(int count) {
    return _locked(() async {
      final List<String> lines = await _readAllLines();
      await _atomicWriteLines(lines.skip(count).toList(growable: false));
    });
  }

  Future<int> count() {
    return _locked(() async {
      final List<String> lines = await _readAllLines();
      int valid = 0;
      for (final String line in lines) {
        if (await _tryDecrypt(line) != null) {
          valid++;
        }
      }
      return valid;
    });
  }

  Future<T> _locked<T>(Future<T> Function() work) {
    final Completer<T> completer = Completer<T>();
    _ops = _ops.then((_) async {
      try {
        completer.complete(await work());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<List<String>> _readAllLines() async {
    final File file = File(_storagePath);
    if (!await file.exists()) {
      await file.create(recursive: true);
      return <String>[];
    }
    final String content = await file.readAsString();
    if (content.trim().isEmpty) {
      return <String>[];
    }
    return content
        .split('\n')
        .where((String item) => item.trim().isNotEmpty)
        .toList();
  }

  Future<void> _atomicWriteLines(List<String> lines) async {
    final File file = File(_storagePath);
    final File tempFile = File('$_storagePath.tmp');
    await tempFile.writeAsString(lines.join('\n'));
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(_storagePath);
  }

  Future<String> _encrypt(String plainText) async {
    final List<int> keyMaterial = sha256.convert(utf8.encode(_encryptionKey)).bytes;
    final SecretKey secretKey = SecretKey(keyMaterial);
    final SecretBox box = await _aes.encrypt(
      utf8.encode(plainText),
      secretKey: secretKey,
    );
    return jsonEncode(<String, dynamic>{
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    });
  }

  Future<String?> _tryDecrypt(String payload) async {
    try {
      final Map<String, dynamic> wrapped = jsonDecode(payload) as Map<String, dynamic>;
      final SecretBox box = SecretBox(
        base64Decode(wrapped['c'] as String),
        nonce: base64Decode(wrapped['n'] as String),
        mac: Mac(base64Decode(wrapped['m'] as String)),
      );
      final List<int> keyMaterial = sha256.convert(utf8.encode(_encryptionKey)).bytes;
      final SecretKey secretKey = SecretKey(keyMaterial);
      final List<int> clear = await _aes.decrypt(box, secretKey: secretKey);
      return Isolate.run(() => utf8.decode(clear));
    } catch (_) {
      return null;
    }
  }

  LogEnvelope _fromJson(Map<String, dynamic> json) {
    final List<dynamic> breadcrumbsJson =
        json['breadcrumbs'] as List<dynamic>? ?? <dynamic>[];
    return LogEnvelope(
      id: json['id'] as String,
      flavor: json['flavor'] as String,
      domain: (json['domain'] as String) == 'INTERNAL'
          ? Domain.internal
          : Domain.external,
      category: _categoryFromName(json['category'] as String),
      level: _levelFromName(json['level'] as String),
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      incidentCustom: Map<String, dynamic>.from(
        json['incidentCustom'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      stackTrace: json['stackTrace'] as String?,
      breadcrumbs: breadcrumbsJson
          .map(
            (item) => Breadcrumb(
              label: item['label'] as String,
              timestamp: DateTime.parse(item['timestamp'] as String),
              metadata: Map<String, dynamic>.from(
                item['metadata'] as Map<String, dynamic>? ??
                    <String, dynamic>{},
              ),
            ),
          )
          .toList(growable: false),
      deviceVitals: _vitalsFromJson(
        json['deviceVitals'] as Map<String, dynamic>?,
      ),
      immediateDispatch: (json['immediateDispatch'] as bool?) ?? false,
      incidentReport: json['incidentReport'] == null
          ? null
          : Map<String, dynamic>.from(json['incidentReport'] as Map),
    );
  }

  DeviceVitalsSnapshot? _vitalsFromJson(Map<String, dynamic>? value) {
    if (value == null) {
      return null;
    }
    final Map<String, dynamic> knownKeys = <String, dynamic>{
      'osVersion': value['osVersion'],
      'deviceModel': value['deviceModel'],
      'manufacturer': value['manufacturer'],
      'deviceName': value['deviceName'],
      'localizedModel': value['localizedModel'],
      'ramUsedBytes': value['ramUsedBytes'],
      'ramFreeBytes': value['ramFreeBytes'],
      'batteryLevel': value['batteryLevel'],
      'chargingState': value['chargingState'],
      'thermalState': value['thermalState'],
    };
    final Map<String, dynamic> extended = Map<String, dynamic>.from(value)
      ..removeWhere((String k, _) => knownKeys.containsKey(k));
    return DeviceVitalsSnapshot(
      osVersion: value['osVersion'] as String? ?? 'unknown',
      deviceModel: value['deviceModel'] as String? ?? 'unknown',
      manufacturer: value['manufacturer'] as String? ?? 'unknown',
      deviceName: value['deviceName'] as String?,
      localizedModel: value['localizedModel'] as String?,
      ramUsedBytes: (value['ramUsedBytes'] as num?)?.toInt() ?? 0,
      ramFreeBytes: (value['ramFreeBytes'] as num?)?.toInt(),
      batteryLevel: (value['batteryLevel'] as num?)?.toDouble(),
      chargingState: value['chargingState'] as String?,
      thermalState: value['thermalState'] as String?,
      extendedDetails: extended,
    );
  }

  LogCategory _categoryFromName(String value) {
    switch (value) {
      case 'UI':
        return LogCategory.ui;
      case 'NETWORK':
        return LogCategory.network;
      case 'SECURE_STORAGE':
        return LogCategory.secureStorage;
      case 'SYSTEM_CRASH':
        return LogCategory.systemCrash;
      case 'SYSTEM':
        return LogCategory.system;
      default:
        return LogCategory.logic;
    }
  }

  LogLevel _levelFromName(String value) {
    switch (value) {
      case 'DEBUG':
        return LogLevel.debug;
      case 'INFO':
        return LogLevel.info;
      case 'WARN':
        return LogLevel.warn;
      case 'ERROR':
        return LogLevel.error;
      case 'FATAL':
        return LogLevel.fatal;
      default:
        return LogLevel.critical;
    }
  }
}
