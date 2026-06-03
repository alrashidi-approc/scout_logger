import 'dart:async';
import 'dart:math';

import '../config/dispatch_policy.dart';
import '../config/logger_config.dart';
import '../models/log_models.dart';
import 'crypto_store.dart';
import 'emergency_dispatch_queue.dart';
import 'network_dispatcher.dart';

class ChronoBatchEngine {
  ChronoBatchEngine({
    required ScoutLoggerConfig config,
    required EncryptedLogStore store,
    required NetworkDispatcher dispatcher,
    EmergencyDispatchQueue? emergencyQueue,
    DateTime Function()? nowProvider,
  })  : _config = config,
        _store = store,
        _dispatcher = dispatcher,
        _emergencyQueue = emergencyQueue,
        _now = nowProvider ?? DateTime.now,
        _lastSyncAt = (nowProvider ?? DateTime.now)();

  final ScoutLoggerConfig _config;
  final EncryptedLogStore _store;
  final NetworkDispatcher _dispatcher;
  final EmergencyDispatchQueue? _emergencyQueue;
  final DateTime Function() _now;
  Timer? _batchTimer;
  Timer? _retryTimer;
  int _retryCount = 0;
  DateTime _lastSyncAt;
  bool _syncInProgress = false;

  void start() {
    if (_config.dispatchPolicy.mode == LogDispatchMode.chronoBatch) {
      _batchTimer?.cancel();
      _batchTimer = Timer.periodic(_config.batchWindow, (_) => syncIfNeeded());
    }
    unawaited(syncIfNeeded(force: true));
  }

  void dispose() {
    _batchTimer?.cancel();
    _retryTimer?.cancel();
  }

  Future<void> enqueue(LogEnvelope envelope) async {
    await _store.insert(envelope);
    if (_config.dispatchPolicy.mode == LogDispatchMode.perLog) {
      await _tryUploadSingle(envelope);
      return;
    }
    final int count = await _store.count();
    if (count >= _config.batchSize) {
      await syncIfNeeded(force: true);
    }
  }

  Future<void> _tryUploadSingle(LogEnvelope envelope) async {
    if (!await _dispatcher.canSyncNow()) {
      _scheduleBackoff();
      return;
    }
    final bool ok = await _dispatcher.uploadSingle(envelope);
    if (ok) {
      await _store.removeFirst(1);
      _retryCount = 0;
      return;
    }
    _scheduleBackoff();
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
    if (_emergencyQueue != null) {
      final bool emergencyOk = await _emergencyQueue!.drain(_dispatcher);
      if (!emergencyOk) {
        _scheduleBackoff();
        return;
      }
    }
    final DateTime now = _now();
    final int queuedCount = await _store.count();
    if (queuedCount == 0) {
      return;
    }
    if (_config.dispatchPolicy.mode == LogDispatchMode.perLog) {
      while (await _store.count() > 0) {
        final List<LogEnvelope> batch = await _store.readBatch(maxItems: 1);
        if (batch.isEmpty) {
          return;
        }
        if (!await _dispatcher.canSyncNow()) {
          _scheduleBackoff();
          return;
        }
        final bool ok = await _dispatcher.uploadSingle(batch.first);
        if (!ok) {
          _scheduleBackoff();
          return;
        }
        await _store.removeFirst(1);
      }
      _retryCount = 0;
      _lastSyncAt = _now();
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
    final int cap = _config.dispatchPolicy.maxRetryBackoffSeconds;
    final int seconds = min(cap, pow(2, _retryCount).toInt());
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), () => syncIfNeeded(force: true));
  }
}
