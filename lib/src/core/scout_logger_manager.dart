import 'dart:async';

import '../config/logger_config.dart';
import '../models/log_models.dart';
import 'batch_engine.dart';
import 'breadcrumbs.dart';
import 'crash_hooks.dart';
import 'crypto_store.dart';
import 'device_metrics.dart';
import 'network_dispatcher.dart';
import 'smart_ui_observer.dart';

class ScoutLogger {
  /// Builds an internal singleton logger instance.
  ScoutLogger._({
    required ScoutLoggerConfig config,
    required ChronoBatchEngine batchEngine,
    required BreadcrumbStore breadcrumbStore,
    required DeviceVitalsCollector deviceVitalsCollector,
    required SmartUIObserver observer,
    required NetworkDispatcher dispatcher,
  })  : _config = config,
        _batchEngine = batchEngine,
        _breadcrumbStore = breadcrumbStore,
        _deviceVitalsCollector = deviceVitalsCollector,
        _observer = observer,
        _dispatcher = dispatcher {
    _crashHooks = CrashHooks.fromLogger(this);
  }

  static ScoutLogger? _instance;

  /// Initializes logging infrastructure and crash hooks once.
  static Future<ScoutLogger> init(ScoutLoggerConfig config) async {
    if (_instance != null) {
      return _instance!;
    }
    final BreadcrumbStore breadcrumbs =
        BreadcrumbStore(maxEntries: config.breadcrumbLimit);
    final EncryptedLogStore store = EncryptedLogStore(config.encryptionKey);
    final NetworkDispatcher dispatcher = NetworkDispatcher(config);
    final ChronoBatchEngine batch = ChronoBatchEngine(
      config: config,
      store: store,
      dispatcher: dispatcher,
    );
    final SmartUIObserver observer = SmartUIObserver(breadcrumbs);
    final ScoutLogger logger = ScoutLogger._(
      config: config,
      batchEngine: batch,
      breadcrumbStore: breadcrumbs,
      deviceVitalsCollector: DeviceVitalsCollector(
        runtimeProbe: config.runtimeVitalsProbe,
      ),
      observer: observer,
      dispatcher: dispatcher,
    );
    logger._crashHooks.install();
    logger._batchEngine.start();
    _instance = logger;
    return logger;
  }

  static ScoutLogger get instance {
    final ScoutLogger? value = _instance;
    if (value == null) {
      throw StateError('ScoutLogger.init must be called before usage.');
    }
    return value;
  }

  final ScoutLoggerConfig _config;
  final ChronoBatchEngine _batchEngine;
  final BreadcrumbStore _breadcrumbStore;
  final DeviceVitalsCollector _deviceVitalsCollector;
  final SmartUIObserver _observer;
  final NetworkDispatcher _dispatcher;
  late final CrashHooks _crashHooks;
  late LogLevel _activeMinimumLevel = _config.minimumLevel;

  /// Observer to plug into `MaterialApp.navigatorObservers`.
  SmartUIObserver get navigatorObserver => _observer;

  /// Applies runtime log-level changes from backend controls.
  Future<void> updateLogLevelsRemote({
    required LogLevel minimumLevel,
    String? userId,
  }) async {
    _activeMinimumLevel = minimumLevel;
    _breadcrumbStore.add(
      Breadcrumb(
        label: 'REMOTE_LOG_LEVEL_UPDATED',
        timestamp: DateTime.now(),
        metadata: <String, dynamic>{'minimumLevel': minimumLevel.name, 'userId': userId},
      ),
    );
  }

  /// Emits a typed log envelope into urgent or batch pipelines.
  Future<void> log({
    required Domain domain,
    required LogCategory category,
    required LogLevel level,
    required String message,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    String? stackTrace,
    bool immediateDispatch = false,
  }) async {
    if (_severity(level) < _severity(_activeMinimumLevel)) {
      return;
    }
    DeviceVitalsSnapshot? vitals;
    if (level == LogLevel.error || level == LogLevel.fatal || level == LogLevel.critical) {
      vitals = await _deviceVitalsCollector.collectAtCrashTime();
    }

    final LogEnvelope envelope = LogEnvelope(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      flavor: _config.flavor,
      domain: domain,
      category: category,
      level: level,
      message: message,
      timestamp: DateTime.now(),
      metadata: metadata,
      stackTrace: stackTrace,
      breadcrumbs: (level == LogLevel.error ||
              level == LogLevel.fatal ||
              level == LogLevel.critical)
          ? _breadcrumbStore.deepCopy()
          : const <Breadcrumb>[],
      deviceVitals: vitals,
      immediateDispatch: immediateDispatch || level == LogLevel.fatal || level == LogLevel.critical,
    );

    if (envelope.immediateDispatch) {
      try {
        await _dispatcher.notifyEmergency(envelope);
      } catch (_) {
        // Keep crash path resilient and non-failing for host apps.
      }
      return;
    }
    await _batchEngine.enqueue(envelope);
  }

  int _severity(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 0;
      case LogLevel.info:
        return 1;
      case LogLevel.warn:
        return 2;
      case LogLevel.error:
        return 3;
      case LogLevel.fatal:
        return 4;
      case LogLevel.critical:
        return 5;
    }
  }
}

/// Public facade that matches the SDK naming in product requirements.
class SmartEyeLogger {
  const SmartEyeLogger._();

  static Future<ScoutLogger> init(ScoutLoggerConfig config) =>
      ScoutLogger.init(config);

  static ScoutLogger get instance => ScoutLogger.instance;
}
