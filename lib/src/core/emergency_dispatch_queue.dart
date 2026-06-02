import 'dart:io';

import '../models/log_models.dart';
import 'crypto_store.dart';
import 'network_dispatcher.dart';

/// Persists failed urgent webhooks and retries them when connectivity allows.
class EmergencyDispatchQueue {
  EmergencyDispatchQueue(
    String encryptionKey, {
    String? storagePath,
  }) : _store = EncryptedLogStore(
          encryptionKey,
          storagePath: storagePath ??
              '${Directory.systemTemp.path}/scout_logger_emergency.enc',
        );

  final EncryptedLogStore _store;

  Future<void> enqueue(LogEnvelope log) =>
      _store.insert(log.copyWith(immediateDispatch: true));

  Future<int> pendingCount() => _store.count();

  /// Sends pending urgent logs in FIFO order. Returns false when blocked or send fails.
  Future<bool> drain(NetworkDispatcher dispatcher) async {
    if (!await dispatcher.canSyncNow()) {
      return false;
    }
    while (true) {
      final List<LogEnvelope> batch =
          await _store.readBatch(maxItems: 1);
      if (batch.isEmpty) {
        return true;
      }
      try {
        await dispatcher.notifyEmergency(batch.first);
      } catch (_) {
        return false;
      }
      await _store.removeFirst(1);
    }
  }
}
