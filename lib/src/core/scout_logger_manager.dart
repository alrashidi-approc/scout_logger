import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

import '../config/blackbox_app_context.dart';
import '../config/network_logging_policy.dart';
import '../config/logger_config.dart';
import '../config/product_insights_policy.dart';
import '../config/production_config_validator.dart';
import '../models/incident_report.dart';
import '../models/log_models.dart';
import 'batch_engine.dart';
import 'connectivity_snapshot.dart';
import 'recent_network_buffer.dart';
import 'breadcrumbs.dart';
import 'crash_hooks.dart';
import 'crypto_store.dart';
import 'device_metrics.dart';
import 'app_context_resolver.dart';
import '../reporting/email_incident_reporter.dart';
import 'emergency_dispatch_queue.dart';
import 'network_dispatcher.dart';
import 'incident_scope.dart';
import 'issue_occurrence_tracker.dart';
import 'scout_lifecycle_binding.dart';
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
    required EmergencyDispatchQueue emergencyQueue,
    EmailIncidentReporter? emailReporter,
    ScoutLifecycleBinding? lifecycleBinding,
  })  : _config = config,
        _batchEngine = batchEngine,
        _breadcrumbStore = breadcrumbStore,
        _deviceVitalsCollector = deviceVitalsCollector,
        _observer = observer,
        _dispatcher = dispatcher,
        _emergencyQueue = emergencyQueue,
        _emailReporter = emailReporter,
        _lifecycleBinding = lifecycleBinding {
    _crashHooks = CrashHooks.fromLogger(this);
    _sessionStartedAt = DateTime.now();
  }

  static ScoutLogger? _instance;

  /// Initializes logging infrastructure and crash hooks once.
  static Future<ScoutLogger> init(ScoutLoggerConfig config) async {
    if (_instance != null) {
      return _instance!;
    }
    assertProductionReadyConfig(config);
    final BlackboxAppContext appContext = config.autoResolveAppInfo
        ? await AppContextResolver.resolve(base: config.appContext)
        : config.appContext;
    final ScoutLoggerConfig resolved = ScoutLoggerConfig(
      flavor: config.flavor,
      bulkUploadHandler: config.bulkUploadHandler,
      emergencyWebhookHandler: config.emergencyWebhookHandler,
      appContext: appContext,
      encryptionKey: config.encryptionKey,
      dispatchPolicy: config.dispatchPolicy,
      serverRouting: config.serverRouting,
      emailReporting: config.emailReporting,
      autoResolveAppInfo: config.autoResolveAppInfo,
      autoCollectDeviceDetails: config.autoCollectDeviceDetails,
      breadcrumbLimit: config.breadcrumbLimit,
      minimumLevel: config.minimumLevel,
      runtimeVitalsProbe: config.runtimeVitalsProbe,
      buildFullIncidentOnWarnOrHigher: config.buildFullIncidentOnWarnOrHigher,
      incidentSharingPolicy: config.incidentSharingPolicy,
      queueStoragePath: config.queueStoragePath,
      emergencyStoragePath: config.emergencyStoragePath,
      connectivityChecker: config.connectivityChecker,
      networkLoggingPolicy: config.networkLoggingPolicy,
      release: config.release,
      environment: config.environment,
      productInsightsPolicy: config.productInsightsPolicy,
    );
    final BreadcrumbStore breadcrumbs =
        BreadcrumbStore(maxEntries: resolved.breadcrumbLimit);
    final EncryptedLogStore store = EncryptedLogStore(
      resolved.encryptionKey,
      storagePath: resolved.queueStoragePath,
    );
    final EmergencyDispatchQueue emergencyQueue = EmergencyDispatchQueue(
      resolved.encryptionKey,
      storagePath: resolved.emergencyStoragePath,
    );
    final NetworkDispatcher dispatcher = NetworkDispatcher(
      resolved,
      connectivityChecker: resolved.connectivityChecker,
    );
    final EmailIncidentReporter? emailReporter = resolved.emailReporting == null
        ? null
        : EmailIncidentReporter(resolved.emailReporting!);
    final ChronoBatchEngine batch = ChronoBatchEngine(
      config: resolved,
      store: store,
      dispatcher: dispatcher,
      emergencyQueue: emergencyQueue,
    );
    final SmartUIObserver observer = SmartUIObserver(breadcrumbs);
    ScoutLifecycleBinding? lifecycleBinding;
    if (resolved.productInsightsPolicy.trackAppLifecycle) {
      lifecycleBinding = ScoutLifecycleBinding(breadcrumbs)..install();
    }
    final ScoutLogger logger = ScoutLogger._(
      config: resolved,
      batchEngine: batch,
      breadcrumbStore: breadcrumbs,
      deviceVitalsCollector: DeviceVitalsCollector(
        runtimeProbe: resolved.runtimeVitalsProbe,
        collectExtendedDetails: resolved.autoCollectDeviceDetails,
      ),
      observer: observer,
      dispatcher: dispatcher,
      emergencyQueue: emergencyQueue,
      emailReporter: emailReporter,
      lifecycleBinding: lifecycleBinding,
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

  @visibleForTesting
  static void resetForTesting() {
    _instance?._lifecycleBinding?.dispose();
    _instance?._batchEngine.dispose();
    _instance = null;
  }

  final ScoutLoggerConfig _config;
  final ChronoBatchEngine _batchEngine;
  final BreadcrumbStore _breadcrumbStore;
  final DeviceVitalsCollector _deviceVitalsCollector;
  final SmartUIObserver _observer;
  final NetworkDispatcher _dispatcher;
  final EmergencyDispatchQueue _emergencyQueue;
  final EmailIncidentReporter? _emailReporter;
  final ScoutLifecycleBinding? _lifecycleBinding;
  late final CrashHooks _crashHooks;
  late LogLevel _activeMinimumLevel = _config.minimumLevel;
  late BlackboxAppContext _appContext = _config.appContext;
  final RecentNetworkBuffer _recentNetwork = RecentNetworkBuffer();
  final IncidentScope _scope = IncidentScope();
  late final DateTime _sessionStartedAt;
  int _sessionIncidentCount = 0;
  final Random _sampleRandom = Random();
  late final IssueOccurrenceTracker _occurrenceTracker = IssueOccurrenceTracker(
    policy: _config.productInsightsPolicy.occurrencePolicy,
  );

  /// Observer to plug into `MaterialApp.navigatorObservers`.
  SmartUIObserver get navigatorObserver => _observer;

  NetworkLoggingPolicy get networkLoggingPolicy => _config.networkLoggingPolicy;

  /// Binds the active user (e.g. after login). Safe to call anytime.
  void bindUser({
    required String userId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) {
    _appContext = _appContext.copyWith(
      userId: userId,
      sessionId: sessionId,
      userMetadata: metadata == null
          ? _appContext.userMetadata
          : <String, dynamic>{..._appContext.userMetadata, ...metadata},
    );
  }

  /// Updates session id without changing user (e.g. app resume).
  void setSessionId(String sessionId) {
    _appContext = _appContext.copyWith(sessionId: sessionId);
  }

  /// Tags indexed by backend for grouping (e.g. feature, team, screen).
  void setTag(String key, String value) => _scope.setTag(key, value);

  void removeTag(String key) => _scope.removeTag(key);

  /// Named context blocks merged into incident `triage.contexts`.
  void setContext(String name, Map<String, dynamic> data) =>
      _scope.setContext(name, data);

  void removeContext(String name) => _scope.removeContext(name);

  void clearScope() => _scope.clear();

  /// Records a product breadcrumb (buttons, flows, business steps).
  void breadcrumb(String label, {Map<String, dynamic>? metadata}) {
    _observer.addManualBreadcrumb(label, metadata: metadata);
  }

  /// Merges persistent metadata into every incident report `custom` section.
  void setGlobalMetadata(Map<String, dynamic> metadata) {
    _appContext = _appContext.copyWith(
      globalMetadata: <String, dynamic>{..._appContext.globalMetadata, ...metadata},
    );
  }

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
    Map<String, dynamic> customMetadata = const <String, dynamic>{},
    String? stackTrace,
    bool immediateDispatch = false,
  }) async {
    if (_severity(level) < _severity(_activeMinimumLevel)) {
      return;
    }
    final bool buildIncident = _shouldBuildIncident(level);
    if (buildIncident && !_canRecordIncident(level)) {
      return;
    }
    if (buildIncident && !_shouldSample(level)) {
      return;
    }

    DeviceVitalsSnapshot? vitals;
    if (buildIncident) {
      vitals = await _deviceVitalsCollector.collectAtCrashTime();
    }

    final List<Breadcrumb> flow =
        buildIncident ? _breadcrumbStore.deepCopy() : const <Breadcrumb>[];
    ConnectivitySnapshot? connectivity;
    if (buildIncident) {
      connectivity = await ConnectivitySnapshot.capture();
    }

    final String id = '${DateTime.now().microsecondsSinceEpoch}';
    final DateTime at = DateTime.now();
    final bool urgent =
        immediateDispatch || level == LogLevel.fatal || level == LogLevel.critical;

    Map<String, dynamic>? incidentReport;
    IncidentOccurrenceDecision? occurrenceDecision;
    if (buildIncident) {
      _sessionIncidentCount++;
      incidentReport = buildIncidentReport(
        envelope: LogEnvelope(
          id: id,
          flavor: _config.flavor,
          domain: domain,
          category: category,
          level: level,
          message: message,
          timestamp: at,
          metadata: metadata,
          incidentCustom: customMetadata,
          stackTrace: stackTrace,
          breadcrumbs: flow,
          deviceVitals: vitals,
          immediateDispatch: urgent,
        ),
        app: _appContext,
        flavor: _config.flavor,
        connectivity: connectivity,
        recentNetwork: _recentNetwork.snapshot(),
        currentRoute: _breadcrumbStore.currentRouteHint(),
        sharingPolicy: _config.incidentSharingPolicy,
        tags: _scope.snapshotTags(),
        contexts: _scope.snapshotContexts(),
        release: _config.release,
        environment: _config.environment,
        sessionStartedAt: _sessionStartedAt,
        sessionIncidentIndex: _sessionIncidentCount,
      );
      final String groupingKey =
          (incidentReport['triage'] as Map<String, dynamic>?)?['groupingKey']
              as String? ??
          '';
      occurrenceDecision = _occurrenceTracker.evaluate(
        groupingKey: groupingKey.isEmpty ? id : groupingKey,
        now: at,
      );
      if (!occurrenceDecision!.shouldUpload) {
        return;
      }
      incidentReport = _attachOccurrence(incidentReport, occurrenceDecision!);
      incidentReport = _applyBeforeSend(incidentReport);
      if (incidentReport == null) {
        return;
      }
    }

    final bool dispatchNow = !buildIncident
        ? urgent
        : urgent &&
            _occurrenceTracker.shouldSendUrgent(
              groupingKey: _groupingKeyFromReport(incidentReport) ?? id,
              decision: occurrenceDecision!,
            );

    final LogEnvelope envelope = LogEnvelope(
      id: id,
      flavor: _config.flavor,
      domain: domain,
      category: category,
      level: level,
      message: message,
      timestamp: at,
      metadata: metadata,
      incidentCustom: customMetadata,
      stackTrace: stackTrace,
      breadcrumbs: flow,
      deviceVitals: vitals,
      incidentReport: incidentReport,
      immediateDispatch: dispatchNow,
    );

    if (category == LogCategory.network) {
      _recentNetwork.record(<String, dynamic>{
        'message': message,
        'level': level.name,
        'at': envelope.timestamp.toIso8601String(),
        ...metadata,
      });
    }

    _emailReporter?.maybeSend(envelope);

    if (envelope.immediateDispatch) {
      try {
        await _dispatcher.notifyEmergency(envelope);
      } catch (_) {
        await _emergencyQueue.enqueue(envelope);
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

  bool _shouldBuildIncident(LogLevel level) =>
      level == LogLevel.error ||
      level == LogLevel.fatal ||
      level == LogLevel.critical ||
      (level == LogLevel.warn && _config.buildFullIncidentOnWarnOrHigher);

  bool _canRecordIncident(LogLevel level) {
    if (level == LogLevel.fatal || level == LogLevel.critical) {
      return true;
    }
    return _sessionIncidentCount < _config.productInsightsPolicy.maxIncidentsPerSession;
  }

  bool _shouldSample(LogLevel level) {
    if (level == LogLevel.fatal || level == LogLevel.critical) {
      return true;
    }
    final double rate = _config.productInsightsPolicy.sampleRate;
    if (rate >= 1.0) {
      return true;
    }
    if (rate <= 0) {
      return false;
    }
    return _sampleRandom.nextDouble() < rate;
  }

  Map<String, dynamic>? _applyBeforeSend(Map<String, dynamic> incident) {
    final BeforeIncidentSend? hook = _config.productInsightsPolicy.beforeIncidentSend;
    if (hook == null) {
      return incident;
    }
    return hook(incident);
  }

  String? _groupingKeyFromReport(Map<String, dynamic>? report) {
    if (report == null) {
      return null;
    }
    return (report['triage'] as Map<String, dynamic>?)?['groupingKey'] as String?;
  }

  Map<String, dynamic> _attachOccurrence(
    Map<String, dynamic> incident,
    IncidentOccurrenceDecision decision,
  ) {
    final Map<String, dynamic> triage = Map<String, dynamic>.from(
      incident['triage'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final String reportReason = switch (decision.reason) {
      IncidentDispatchReason.first => 'first',
      IncidentDispatchReason.rollup => 'rollup',
      IncidentDispatchReason.suppressed => 'suppressed',
    };
    triage['occurrence'] = <String, dynamic>{
      'count': decision.totalCount,
      'sinceLastReport': decision.pendingSinceLastReport,
      'reportReason': reportReason,
      'firstSeenAt': decision.firstSeenAt?.toUtc().toIso8601String(),
      'lastSeenAt': decision.lastSeenAt?.toUtc().toIso8601String(),
    };
    return <String, dynamic>{...incident, 'triage': triage};
  }
}

/// Public facade for Scout App Logger.
class ScoutAppLogger {
  const ScoutAppLogger._();

  static Future<ScoutLogger> init(ScoutLoggerConfig config) =>
      ScoutLogger.init(config);

  static ScoutLogger get instance => ScoutLogger.instance;

  static void bindUser({
    required String userId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) =>
      ScoutLogger.instance.bindUser(
        userId: userId,
        sessionId: sessionId,
        metadata: metadata,
      );

  static void setSessionId(String sessionId) =>
      ScoutLogger.instance.setSessionId(sessionId);

  static void setGlobalMetadata(Map<String, dynamic> metadata) =>
      ScoutLogger.instance.setGlobalMetadata(metadata);

  static Future<void> updateLogLevelsRemote({
    required LogLevel minimumLevel,
    String? userId,
  }) =>
      ScoutLogger.instance.updateLogLevelsRemote(
        minimumLevel: minimumLevel,
        userId: userId,
      );

  static Future<void> log({
    required Domain domain,
    required LogCategory category,
    required LogLevel level,
    required String message,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> customMetadata = const <String, dynamic>{},
    String? stackTrace,
    bool immediateDispatch = false,
  }) =>
      ScoutLogger.instance.log(
        domain: domain,
        category: category,
        level: level,
        message: message,
        metadata: metadata,
        customMetadata: customMetadata,
        stackTrace: stackTrace,
        immediateDispatch: immediateDispatch,
      );

  static void setTag(String key, String value) =>
      ScoutLogger.instance.setTag(key, value);

  static void setContext(String name, Map<String, dynamic> data) =>
      ScoutLogger.instance.setContext(name, data);

  static void breadcrumb(String label, {Map<String, dynamic>? metadata}) =>
      ScoutLogger.instance.breadcrumb(label, metadata: metadata);
}

@Deprecated('Use ScoutAppLogger instead.')
typedef SmartEyeLogger = ScoutAppLogger;
