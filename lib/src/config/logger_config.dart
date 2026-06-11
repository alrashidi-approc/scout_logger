import 'package:meta/meta.dart';

import 'connectivity_checker.dart';
import 'sdk_constants.dart';
import '../models/log_models.dart';
import 'blackbox_app_context.dart';
import 'dispatch_policy.dart';
import 'email_reporting_config.dart';
import 'incident_sharing_policy.dart';
import 'log_server_routing.dart';
import 'network_logging_policy.dart';
import 'product_insights_policy.dart';
import 'upload_handlers.dart';

export 'upload_handlers.dart';

class ScoutLoggerConfig {
  const ScoutLoggerConfig({
    required this.flavor,
    required this.bulkUploadHandler,
    required this.emergencyWebhookHandler,
    required this.appContext,
    this.encryptionKey = kScoutLoggerDefaultEncryptionKey,
    this.dispatchPolicy = const LogDispatchPolicy(),
    this.serverRouting,
    this.emailReporting,
    this.autoResolveAppInfo = false,
    this.autoCollectDeviceDetails = true,
    this.breadcrumbLimit = 50,
    this.minimumLevel = LogLevel.info,
    this.runtimeVitalsProbe,
    this.buildFullIncidentOnWarnOrHigher = true,
    this.incidentSharingPolicy = const IncidentSharingPolicy(),
    this.queueStoragePath,
    this.emergencyStoragePath,
    @visibleForTesting this.connectivityChecker,
    this.networkLoggingPolicy = NetworkLoggingPolicy.defaults,
    this.release,
    this.environment,
    this.productInsightsPolicy = const ProductInsightsPolicy(),
  });

  final String flavor;
  final BulkUploadHandler bulkUploadHandler;
  final EmergencyWebhookHandler emergencyWebhookHandler;
  final BlackboxAppContext appContext;
  final String encryptionKey;
  final LogDispatchPolicy dispatchPolicy;
  final LogServerRouting? serverRouting;
  final EmailReportingConfig? emailReporting;
  final bool autoResolveAppInfo;
  final bool autoCollectDeviceDetails;
  final int breadcrumbLimit;
  final LogLevel minimumLevel;
  final RuntimeVitalsProbe? runtimeVitalsProbe;
  final bool buildFullIncidentOnWarnOrHigher;
  final IncidentSharingPolicy incidentSharingPolicy;
  final String? queueStoragePath;
  final String? emergencyStoragePath;
  final ConnectivityChecker? connectivityChecker;
  final NetworkLoggingPolicy networkLoggingPolicy;
  final String? release;
  final String? environment;
  final ProductInsightsPolicy productInsightsPolicy;

  int get batchSize => dispatchPolicy.batchSize;
  Duration get batchWindow => dispatchPolicy.batchWindow;
  bool get wifiOnlySync => dispatchPolicy.wifiOnlySync;

  factory ScoutLoggerConfig.blackbox({
    required String flavor,
    BlackboxAppContext? appContext,
    /// Backend partition label (e.g. `Diyar Wallet`). Overrides [BlackboxAppContext.appName].
    String? appName,
    bool autoResolveAppInfo = true,
    required BlackboxBulkUploadHandler onBatchIncidents,
    required BlackboxEmergencyHandler onUrgentIncident,
    BlackboxSingleUploadHandler? onSingleIncident,
    LogServerRouting? serverRouting,
    LogDispatchPolicy dispatchPolicy = const LogDispatchPolicy(),
    EmailReportingConfig? emailReporting,
    String encryptionKey = kScoutLoggerDefaultEncryptionKey,
    bool autoCollectDeviceDetails = true,
    int breadcrumbLimit = 50,
    LogLevel minimumLevel = LogLevel.info,
    RuntimeVitalsProbe? runtimeVitalsProbe,
    bool buildFullIncidentOnWarnOrHigher = true,
    IncidentSharingPolicy incidentSharingPolicy = const IncidentSharingPolicy(),
    NetworkLoggingPolicy networkLoggingPolicy = NetworkLoggingPolicy.defaults,
    String? release,
    String? environment,
    ProductInsightsPolicy productInsightsPolicy = const ProductInsightsPolicy(),
  }) {
    BulkUploadHandler bulk = (List<LogEnvelope> logs) async {
      final List<String> incidents = <String>[
        for (final LogEnvelope log in logs)
          if (log.incidentReport != null) log.toIncidentJson(),
      ];
      if (incidents.isEmpty) {
        return true;
      }
      return onBatchIncidents(incidents);
    };

    if (serverRouting != null) {
      bulk = (List<LogEnvelope> logs) async {
        final Map<LogCategory, List<LogEnvelope>> groups = <LogCategory, List<LogEnvelope>>{};
        for (final LogEnvelope log in logs) {
          (groups[log.category] ??= <LogEnvelope>[]).add(log);
        }
        for (final MapEntry<LogCategory, List<LogEnvelope>> entry in groups.entries) {
          final bool ok = await serverRouting.bulkFor(entry.key)(entry.value);
          if (!ok) {
            return false;
          }
        }
        return true;
      };
    }

    final LogDispatchPolicy policy =
        dispatchPolicy.mode == LogDispatchMode.perLog || onSingleIncident != null
            ? LogDispatchPolicy(
                mode: LogDispatchMode.perLog,
                batchSize: dispatchPolicy.batchSize,
                batchWindow: dispatchPolicy.batchWindow,
                wifiOnlySync: dispatchPolicy.wifiOnlySync,
                maxRetryBackoffSeconds: dispatchPolicy.maxRetryBackoffSeconds,
              )
            : dispatchPolicy;

    if (onSingleIncident != null) {
      bulk = (List<LogEnvelope> logs) async {
        for (final LogEnvelope log in logs) {
          if (log.incidentReport == null) {
            continue;
          }
          final bool ok = await onSingleIncident(log.toIncidentJson());
          if (!ok) {
            return false;
          }
        }
        return true;
      };
    }

    final BlackboxAppContext resolvedContext = _resolveBlackboxAppContext(
      appContext: appContext,
      appName: appName,
    );

    return ScoutLoggerConfig(
      flavor: flavor,
      appContext: resolvedContext,
      autoResolveAppInfo: autoResolveAppInfo,
      encryptionKey: encryptionKey,
      dispatchPolicy: policy,
      serverRouting: serverRouting,
      emailReporting: emailReporting,
      autoCollectDeviceDetails: autoCollectDeviceDetails,
      breadcrumbLimit: breadcrumbLimit,
      minimumLevel: minimumLevel,
      runtimeVitalsProbe: runtimeVitalsProbe,
      buildFullIncidentOnWarnOrHigher: buildFullIncidentOnWarnOrHigher,
      incidentSharingPolicy: incidentSharingPolicy,
      networkLoggingPolicy: networkLoggingPolicy,
      release: release,
      environment: environment,
      productInsightsPolicy: productInsightsPolicy,
      bulkUploadHandler: bulk,
      emergencyWebhookHandler: (LogEnvelope log) => onUrgentIncident(log.toIncidentJson()),
    );
  }

  static BlackboxAppContext _resolveBlackboxAppContext({
    BlackboxAppContext? appContext,
    String? appName,
  }) {
    final BlackboxAppContext base = appContext ??
        const BlackboxAppContext(
          appVersion: '0.0.0',
          buildNumber: '0',
          packageName: 'unknown',
        );
    final String? trimmed = appName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return base;
    }
    return base.copyWith(appName: trimmed);
  }
}

typedef RuntimeVitalsProbe = Future<Map<String, dynamic>> Function();
