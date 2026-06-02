import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/core/crypto_store.dart';
import 'package:scout_logger/src/models/log_models.dart';

void main() {
  test('stores and reads encrypted logs with vitals', () async {
    final String path = _tempPath('store_roundtrip');
    final EncryptedLogStore store = EncryptedLogStore('secret', storagePath: path);
    final LogEnvelope log = LogEnvelope(
      id: '1',
      flavor: 'production',
      domain: Domain.internal,
      category: LogCategory.systemCrash,
      level: LogLevel.error,
      message: 'boom',
      timestamp: DateTime.parse('2026-06-02T00:00:00.000Z'),
      deviceVitals: const DeviceVitalsSnapshot(
        osVersion: '17',
        deviceModel: 'iPhone',
        manufacturer: 'Apple',
        ramUsedBytes: 128,
      ),
    );

    await store.insert(log);
    final List<LogEnvelope> batch = await store.readBatch(maxItems: 10);

    expect(batch, hasLength(1));
    expect(batch.first.message, 'boom');
    expect(batch.first.deviceVitals?.deviceModel, 'iPhone');
    await _cleanup(path);
  });

  test('appends multiple inserts after file has lines', () async {
    final String path = _tempPath('store_append');
    final EncryptedLogStore store = EncryptedLogStore('secret', storagePath: path);
    final LogEnvelope first = LogEnvelope(
      id: '1',
      flavor: 'test',
      domain: Domain.internal,
      category: LogCategory.logic,
      level: LogLevel.info,
      message: 'first',
      timestamp: DateTime.now(),
    );
    await store.insert(first);
    await store.insert(first.copyWith(id: '2', message: 'second'));
    expect(await store.count(), 2);
    final List<LogEnvelope> batch = await store.readBatch(maxItems: 10);
    expect(batch.map((LogEnvelope e) => e.message).toList(), <String>['first', 'second']);
    await _cleanup(path);
  });

  test('skips corrupted records without breaking queue', () async {
    final String path = _tempPath('store_corrupt');
    final EncryptedLogStore store = EncryptedLogStore('secret', storagePath: path);
    await store.insert(
      LogEnvelope(
        id: '1',
        flavor: 'test',
        domain: Domain.external,
        category: LogCategory.network,
        level: LogLevel.info,
        message: 'ok',
        timestamp: DateTime.now(),
      ),
    );

    final File file = File(path);
    await file.writeAsString('${await file.readAsString()}\nnot-json');
    expect(await store.count(), 1);
    final List<LogEnvelope> batch = await store.readBatch(maxItems: 10);
    expect(batch, hasLength(1));
    expect(batch.first.message, 'ok');
    await _cleanup(path);
  });
}

String _tempPath(String suffix) =>
    '${Directory.systemTemp.path}/scout_logger_${suffix}_${DateTime.now().microsecondsSinceEpoch}.enc';

Future<void> _cleanup(String path) async {
  final File file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
