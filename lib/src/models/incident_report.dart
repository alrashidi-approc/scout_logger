import 'dart:convert';
import 'dart:io';

import '../config/blackbox_app_context.dart';
import '../config/incident_sharing_policy.dart';
import '../core/connectivity_snapshot.dart';
import '../config/sdk_constants.dart';
import '../util/incident_time_format.dart';
import 'log_models.dart';

const String kIncidentSchemaVersion = '1.1';

Map<String, dynamic> buildIncidentReport({
  required LogEnvelope envelope,
  required BlackboxAppContext app,
  required String flavor,
  ConnectivitySnapshot? connectivity,
  List<Map<String, dynamic>> recentNetwork = const <Map<String, dynamic>>[],
  String? currentRoute,
  IncidentSharingPolicy sharingPolicy = const IncidentSharingPolicy(),
}) {
  final IncidentSectionSet sections =
      sharingPolicy.resolveSections(envelope.level, envelope.category);
  final Map<String, dynamic> time = formatIncidentTime(envelope.timestamp);

  Map<String, dynamic>? device;
  if (sections.device) {
    device = envelope.deviceVitals?.toJson();
  }

  Map<String, dynamic>? connectivityJson;
  if (sections.connectivity) {
    connectivityJson = connectivity?.toJson();
  }

  Map<String, dynamic>? screen;
  if (sections.screen) {
    screen = <String, dynamic>{
      'currentRoute': currentRoute,
      'userFlow': sections.includeUserFlow
          ? envelope.breadcrumbs.map((Breadcrumb b) => _breadcrumbJson(b)).toList()
          : <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic>? network;
  if (sections.network) {
    final Map<String, dynamic>? triggering = envelope.category == LogCategory.network
        ? normalizeDurationsInMap(Map<String, dynamic>.from(envelope.metadata))
        : null;
    network = <String, dynamic>{
      'triggering': triggering,
      'recent': recentNetwork.map(normalizeDurationsInMap).toList(growable: false),
    };
  }

  Map<String, dynamic>? custom;
  if (sections.custom) {
    custom = <String, dynamic>{
      ...app.globalMetadata,
      ...envelope.metadata,
    };
  }

  final Map<String, dynamic> user = <String, dynamic>{
    'userId': app.userId,
    'sessionId': app.sessionId,
    if (app.userMetadata.isNotEmpty) 'metadata': app.userMetadata,
  };

  return <String, dynamic>{
    'schemaVersion': kIncidentSchemaVersion,
    'incidentId': envelope.id,
    'time': time,
    'timestamp': time['utc'],
    'event': <String, dynamic>{
      'level': _levelName(envelope.level),
      'category': _categoryName(envelope.category),
      'domain': envelope.domain == Domain.internal ? 'INTERNAL' : 'EXTERNAL',
      'message': envelope.message,
      'stackTrace': sections.includeStackTrace ? envelope.stackTrace : null,
      'immediateDispatch': envelope.immediateDispatch,
    },
    'app': <String, dynamic>{
      'flavor': flavor,
      'version': app.appVersion,
      'buildNumber': app.buildNumber,
      'packageName': app.packageName,
      'sdkVersion': kScoutLoggerSdkVersion,
      'platform': Platform.operatingSystem,
    },
    'user': user,
    'device': device,
    'connectivity': connectivityJson,
    'screen': screen,
    'network': network,
    'custom': custom,
    'payload': <String, dynamic>{
      'detailLevel': sharingPolicy.resolveLevel(envelope.level, envelope.category).name,
      'sectionsIncluded': <String, dynamic>{
        'device': sections.device,
        'connectivity': sections.connectivity,
        'screen': sections.screen,
        'network': sections.network,
        'custom': sections.custom,
        'userFlow': sections.includeUserFlow,
        'stackTrace': sections.includeStackTrace,
      },
    },
  };
}

Map<String, dynamic> _breadcrumbJson(Breadcrumb breadcrumb) {
  return <String, dynamic>{
    'label': breadcrumb.label,
    'time': formatIncidentTime(breadcrumb.timestamp),
    'timestamp': breadcrumb.timestamp.toUtc().toIso8601String(),
    'metadata': breadcrumb.metadata,
  };
}

String incidentReportToJson(Map<String, dynamic> report) => jsonEncode(report);

String _levelName(LogLevel level) {
  switch (level) {
    case LogLevel.debug:
      return 'DEBUG';
    case LogLevel.info:
      return 'INFO';
    case LogLevel.warn:
      return 'WARN';
    case LogLevel.error:
      return 'ERROR';
    case LogLevel.fatal:
      return 'FATAL';
    case LogLevel.critical:
      return 'CRITICAL';
  }
}

String _categoryName(LogCategory category) {
  switch (category) {
    case LogCategory.ui:
      return 'UI';
    case LogCategory.network:
      return 'NETWORK';
    case LogCategory.secureStorage:
      return 'SECURE_STORAGE';
    case LogCategory.systemCrash:
      return 'SYSTEM_CRASH';
    case LogCategory.system:
      return 'SYSTEM';
    case LogCategory.logic:
      return 'LOGIC';
  }
}
