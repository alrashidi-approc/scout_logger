import 'dart:convert';

enum Domain { external, internal }

enum LogLevel { debug, info, warn, error, fatal, critical }

enum LogCategory { ui, network, secureStorage, systemCrash, system, logic }

class Breadcrumb {
  const Breadcrumb({
    required this.label,
    required this.timestamp,
    this.metadata = const <String, dynamic>{},
  });

  final String label;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };
}

class DeviceVitalsSnapshot {
  const DeviceVitalsSnapshot({
    required this.osVersion,
    required this.deviceModel,
    required this.manufacturer,
    required this.ramUsedBytes,
    this.ramFreeBytes,
    this.batteryLevel,
    this.chargingState,
    this.thermalState,
    this.extendedDetails = const <String, dynamic>{},
  });

  final String osVersion;
  final String deviceModel;
  final String manufacturer;
  final int ramUsedBytes;
  final int? ramFreeBytes;
  final double? batteryLevel;
  final String? chargingState;
  final String? thermalState;
  final Map<String, dynamic> extendedDetails;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'osVersion': osVersion,
        'deviceModel': deviceModel,
        'manufacturer': manufacturer,
        'ramUsedBytes': ramUsedBytes,
        'ramFreeBytes': ramFreeBytes,
        'batteryLevel': batteryLevel,
        'chargingState': chargingState,
        'thermalState': thermalState,
        ...extendedDetails,
      };
}

class LogEnvelope {
  const LogEnvelope({
    required this.id,
    required this.flavor,
    required this.domain,
    required this.category,
    required this.level,
    required this.message,
    required this.timestamp,
    this.metadata = const <String, dynamic>{},
    this.stackTrace,
    this.breadcrumbs = const <Breadcrumb>[],
    this.deviceVitals,
    this.immediateDispatch = false,
    this.incidentReport,
  });

  final String id;
  final String flavor;
  final Domain domain;
  final LogCategory category;
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final String? stackTrace;
  final List<Breadcrumb> breadcrumbs;
  final DeviceVitalsSnapshot? deviceVitals;
  final bool immediateDispatch;
  /// Single JSON-ready map: user, device, connectivity, screen flow, API, stack, custom.
  final Map<String, dynamic>? incidentReport;

  bool get isErrorOrHigher =>
      level == LogLevel.error ||
      level == LogLevel.fatal ||
      level == LogLevel.critical;

  bool get isFatalOrCritical =>
      level == LogLevel.fatal || level == LogLevel.critical;

  LogEnvelope copyWith({
    String? id,
    String? flavor,
    Domain? domain,
    LogCategory? category,
    LogLevel? level,
    String? message,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    String? stackTrace,
    List<Breadcrumb>? breadcrumbs,
    DeviceVitalsSnapshot? deviceVitals,
    bool? immediateDispatch,
    Map<String, dynamic>? incidentReport,
  }) {
    return LogEnvelope(
      id: id ?? this.id,
      flavor: flavor ?? this.flavor,
      domain: domain ?? this.domain,
      category: category ?? this.category,
      level: level ?? this.level,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      stackTrace: stackTrace ?? this.stackTrace,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      deviceVitals: deviceVitals ?? this.deviceVitals,
      immediateDispatch: immediateDispatch ?? this.immediateDispatch,
      incidentReport: incidentReport ?? this.incidentReport,
    );
  }

  /// Full incident document as JSON string (for blackbox upload handlers).
  String toIncidentJson() => jsonEncode(incidentReport ?? toJson());

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'flavor': flavor,
        'domain': _domainName(domain),
        'category': _categoryName(category),
        'level': _levelName(level),
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
        'stackTrace': stackTrace,
        'breadcrumbs': breadcrumbs.map((item) => item.toJson()).toList(),
        'deviceVitals': deviceVitals?.toJson(),
        'immediateDispatch': immediateDispatch,
        if (incidentReport != null) 'incidentReport': incidentReport,
      };

  String toCompactJson() => jsonEncode(toJson());

  String _domainName(Domain value) =>
      value == Domain.internal ? 'INTERNAL' : 'EXTERNAL';

  String _levelName(LogLevel value) {
    switch (value) {
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

  String _categoryName(LogCategory value) {
    switch (value) {
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
}
