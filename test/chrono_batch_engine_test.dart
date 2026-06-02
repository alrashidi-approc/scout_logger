import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/dispatch_policy.dart';
import 'package:scout_logger/src/config/logger_config.dart';

import 'test_helpers.dart';
import 'package:scout_logger/src/core/batch_engine.dart';
import 'package:scout_logger/src/core/crypto_store.dart';
import 'package:scout_logger/src/core/network_dispatcher.dart';
import 'package:scout_logger/src/models/log_models.dart';

void main() {
  test('syncs by window even if count is below batch size', () async {
    DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
    final _InMemoryStore store = _InMemoryStore();
    final _FakeDispatcher dispatcher = _FakeDispatcher(_config);
    final ChronoBatchEngine engine = ChronoBatchEngine(
      config: _config,
      store: store,
      dispatcher: dispatcher,
      nowProvider: () => now,
    );
    await store.insert(_log);

    await engine.syncIfNeeded();
    expect(dispatcher.uploadedBatches, isEmpty);

    now = now.add(const Duration(seconds: 121));
    await engine.syncIfNeeded();
    expect(dispatcher.uploadedBatches.length, 1);
    expect(dispatcher.uploadedBatches.first.length, 1);
  });

  test('force sync drains queue in configured batch chunks', () async {
    final ScoutLoggerConfig config = ScoutLoggerConfig(
      flavor: 'test',
      appContext: kTestAppContext,
      bulkUploadHandler: _noopBulk,
      emergencyWebhookHandler: _noopEmergency,
      dispatchPolicy: const LogDispatchPolicy(batchSize: 2),
    );
    final _InMemoryStore store = _InMemoryStore();
    final _FakeDispatcher dispatcher = _FakeDispatcher(config);
    final ChronoBatchEngine engine = ChronoBatchEngine(
      config: config,
      store: store,
      dispatcher: dispatcher,
    );
    await store.insert(_log);
    await store.insert(_log.copyWith(id: '2'));
    await store.insert(_log.copyWith(id: '3'));
    await store.insert(_log.copyWith(id: '4'));
    await store.insert(_log.copyWith(id: '5'));

    await engine.syncIfNeeded(force: true);

    expect(dispatcher.uploadedBatches.map((e) => e.length).toList(), <int>[2, 2, 1]);
    expect(await store.count(), 0);
  });
}

final ScoutLoggerConfig _config = testLoggerConfig(
  bulkUploadHandler: _noopBulk,
  emergencyWebhookHandler: _noopEmergency,
);

Future<bool> _noopBulk(List<LogEnvelope> logs) async => true;
Future<void> _noopEmergency(LogEnvelope log) async {}

final LogEnvelope _log = LogEnvelope(
  id: '1',
  flavor: 'test',
  domain: Domain.internal,
  category: LogCategory.logic,
  level: LogLevel.info,
  message: 'test',
  timestamp: DateTime(2026, 1, 1),
);

class _InMemoryStore extends EncryptedLogStore {
  _InMemoryStore() : super('test');

  final List<LogEnvelope> _logs = <LogEnvelope>[];

  @override
  Future<void> insert(LogEnvelope log) async => _logs.add(log);

  @override
  Future<List<LogEnvelope>> readBatch({required int maxItems}) async =>
      _logs.take(maxItems).toList(growable: false);

  @override
  Future<void> removeFirst(int count) async => _logs.removeRange(0, count);

  @override
  Future<int> count() async => _logs.length;
}

class _FakeDispatcher extends NetworkDispatcher {
  _FakeDispatcher(ScoutLoggerConfig config) : super(config);

  final List<List<LogEnvelope>> uploadedBatches = <List<LogEnvelope>>[];

  @override
  Future<bool> canSyncNow() async => true;

  @override
  Future<bool> uploadBatch(List<LogEnvelope> logs) async {
    uploadedBatches.add(logs);
    return true;
  }
}
