import 'dart:async';
import 'dart:math';

import '../config/logger_config.dart';
import '../models/log_models.dart';
import 'crypto_store.dart';
import 'network_dispatcher.dart';

class ChronoBatchEngine {
  ChronoBatchEngine({
    required ScoutLoggerConfig config,
    required EncryptedLogStore store,
    required NetworkDispatcher dispatcher,
    DateTime Function()? nowProvider,
  })  : _config = config,
        _store = store,
        _dispatcher = dispatcher,
        _now = nowProvider ?? DateTime.now,
        _lastSyncAt = (nowProvider ?? DateTime.now)();

  final ScoutLoggerConfig _config;
  final EncryptedLogStore _store;
  final NetworkDispatcher _dispatcher;
  final DateTime Function() _now;
  Timer? _batchTimer;
  Timer? _retryTimer;
  int _retryCount = 0;
  DateTime _lastSyncAt;
  bool _syncInProgress = false;

  void start() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(_config.batchWindow, (_) => syncIfNeeded());
  }

  void dispose() {
    _batchTimer?.cancel();
    _retryTimer?.cancel();
  }

  Future<void> enqueue(LogEnvelope envelope) async {
    await _store.insert(envelope);
    final int count = await _store.count();
    if (count >= _config.batchSize) {
      await syncIfNeeded(force: true);
    }
  }

  Future<void> syncIfNeeded({bool force = false}) async {
    if (_syncInProgress) {
      return;
    }
    _syncInProgress = true;
    try {
      await _syncIfNeededInternal(force: force);
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _syncIfNeededInternal({required bool force}) async {
    final DateTime now = _now();
    final int queuedCount = await _store.count();
    if (queuedCount == 0) {
      return;
    }
    final bool shouldSyncByTime = now.difference(_lastSyncAt) >= _config.batchWindow;
    if (!force && queuedCount < _config.batchSize && !shouldSyncByTime) {
      return;
    }
    if (!await _dispatcher.canSyncNow()) {
      _scheduleBackoff();
      return;
    }
    while (true) {
      final List<LogEnvelope> batch = await _store.readBatch(maxItems: _config.batchSize);
      if (batch.isEmpty) {
        return;
      }
      final bool ok = await _dispatcher.uploadBatch(batch);
      if (!ok) {
        _scheduleBackoff();
        return;
      }
      _retryCount = 0;
      _lastSyncAt = _now();
      await _store.removeFirst(batch.length);
      if (!force) {
        return;
      }
    }
  }

  void _scheduleBackoff() {
    _retryCount++;
    final int seconds = min(300, pow(2, _retryCount).toInt());
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), () => syncIfNeeded(force: true));
  }
}
