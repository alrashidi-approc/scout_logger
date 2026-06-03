import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/core/crypto_store.dart';
import 'package:scout_logger/src/config/logger_config.dart';

import 'test_helpers.dart';
import 'package:scout_logger/src/core/batch_engine.dart';
import 'package:scout_logger/src/core/emergency_dispatch_queue.dart';
import 'package:scout_logger/src/core/network_dispatcher.dart';
import 'package:scout_logger/src/models/log_models.dart';

void main() {
  test('persists failed urgent logs and drains on sync', () async {
    final String storagePath =
        '${Directory.systemTemp.path}/scout_logger_emergency_test_${DateTime.now().microsecondsSinceEpoch}.enc';
    final EmergencyDispatchQueue queue = EmergencyDispatchQueue(
      'test-key',
      storagePath: storagePath,
    );
    final _FlakyEmergencyDispatcher dispatcher = _FlakyEmergencyDispatcher(
      testLoggerConfig(
        bulkUploadHandler: _noopBulk,
        emergencyWebhookHandler: _noopEmergency,
      ),
    );
    final ChronoBatchEngine engine = ChronoBatchEngine(
      config: dispatcher.config,
      store: _NoopBatchStore(),
      dispatcher: dispatcher,
      emergencyQueue: queue,
    );

    await queue.enqueue(_urgentLog);
    expect(await queue.pendingCount(), 1);

    await engine.syncIfNeeded(force: true);
    expect(dispatcher.attempts, 1);
    expect(await queue.pendingCount(), 1);

    dispatcher.shouldFail = false;
    await engine.syncIfNeeded(force: true);
    expect(dispatcher.attempts, 2);
    expect(await queue.pendingCount(), 0);
    expect(dispatcher.delivered.length, 1);
    expect(dispatcher.delivered.first.id, 'urgent-1');
  });
}

Future<bool> _noopBulk(List<LogEnvelope> logs) async => true;
Future<void> _noopEmergency(LogEnvelope log) async {}

final LogEnvelope _urgentLog = LogEnvelope(
  id: 'urgent-1',
  flavor: 'test',
  domain: Domain.internal,
  category: LogCategory.systemCrash,
  level: LogLevel.fatal,
  message: 'crash',
  timestamp: DateTime(2026, 1, 1),
  immediateDispatch: true,
);

class _NoopBatchStore extends EncryptedLogStore {
  _NoopBatchStore() : super('test');

  @override
  Future<void> insert(LogEnvelope log) async {}

  @override
  Future<List<LogEnvelope>> readBatch({required int maxItems}) async =>
      const <LogEnvelope>[];

  @override
  Future<void> removeFirst(int count) async {}

  @override
  Future<int> count() async => 0;
}

class _FlakyEmergencyDispatcher extends NetworkDispatcher {
  _FlakyEmergencyDispatcher(this.config) : super(config);

  final ScoutLoggerConfig config;
  bool shouldFail = true;
  int attempts = 0;
  final List<LogEnvelope> delivered = <LogEnvelope>[];

  @override
  Future<bool> canSyncNow() async => true;

  @override
  Future<void> notifyEmergency(LogEnvelope log) async {
    attempts++;
    if (shouldFail) {
      throw StateError('webhook down');
    }
    delivered.add(log);
  }
}
