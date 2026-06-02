import '../models/log_models.dart';

/// How much context each incident JSON includes (same keys always; omitted sections are `null`).
enum IncidentDetailLevel {
  /// Event + app + user only; other top-level keys are present but `null`.
  minimal,

  /// Smart sections for [LogCategory] / [LogLevel] (recommended).
  focused,

  /// Every section populated when data exists.
  full,
}

class IncidentSectionSet {
  const IncidentSectionSet({
    required this.device,
    required this.connectivity,
    required this.screen,
    required this.network,
    required this.custom,
    required this.includeStackTrace,
    required this.includeUserFlow,
  });

  final bool device;
  final bool connectivity;
  final bool screen;
  final bool network;
  final bool custom;
  final bool includeStackTrace;
  final bool includeUserFlow;

  static const IncidentSectionSet none = IncidentSectionSet(
    device: false,
    connectivity: false,
    screen: false,
    network: false,
    custom: false,
    includeStackTrace: false,
    includeUserFlow: false,
  );

  static const IncidentSectionSet all = IncidentSectionSet(
    device: true,
    connectivity: true,
    screen: true,
    network: true,
    custom: true,
    includeStackTrace: true,
    includeUserFlow: true,
  );
}

/// Controls payload size: not every error needs device + network + full flow.
class IncidentSharingPolicy {
  const IncidentSharingPolicy({
    this.defaultLevel = IncidentDetailLevel.focused,
    this.byLevel = const <LogLevel, IncidentDetailLevel>{},
    this.byCategory = const <LogCategory, IncidentDetailLevel>{},
    this.fullPayloadLevels = const <LogLevel>{
      LogLevel.fatal,
      LogLevel.critical,
    },
  });

  final IncidentDetailLevel defaultLevel;
  final Map<LogLevel, IncidentDetailLevel> byLevel;
  final Map<LogCategory, IncidentDetailLevel> byCategory;

  /// These levels always use [IncidentDetailLevel.full] unless overridden by [byLevel].
  final Set<LogLevel> fullPayloadLevels;

  IncidentDetailLevel resolveLevel(LogLevel level, LogCategory category) {
    if (fullPayloadLevels.contains(level)) {
      return byLevel[level] ?? IncidentDetailLevel.full;
    }
    return byLevel[level] ?? byCategory[category] ?? defaultLevel;
  }

  IncidentSectionSet resolveSections(LogLevel level, LogCategory category) {
    switch (resolveLevel(level, category)) {
      case IncidentDetailLevel.minimal:
        return IncidentSectionSet.none;
      case IncidentDetailLevel.full:
        return IncidentSectionSet.all;
      case IncidentDetailLevel.focused:
        return _focusedSections(category, level);
    }
  }

  IncidentSectionSet _focusedSections(LogCategory category, LogLevel level) {
    final bool isHigh =
        level == LogLevel.error || level == LogLevel.fatal || level == LogLevel.critical;
    switch (category) {
      case LogCategory.network:
        return IncidentSectionSet(
          device: isHigh,
          connectivity: true,
          screen: isHigh,
          network: true,
          custom: true,
          includeStackTrace: isHigh,
          includeUserFlow: isHigh,
        );
      case LogCategory.systemCrash:
        return const IncidentSectionSet(
          device: true,
          connectivity: true,
          screen: true,
          network: false,
          custom: true,
          includeStackTrace: true,
          includeUserFlow: true,
        );
      case LogCategory.ui:
        return IncidentSectionSet(
          device: isHigh,
          connectivity: isHigh,
          screen: true,
          network: false,
          custom: true,
          includeStackTrace: isHigh,
          includeUserFlow: true,
        );
      case LogCategory.secureStorage:
        return IncidentSectionSet(
          device: isHigh,
          connectivity: false,
          screen: isHigh,
          network: false,
          custom: true,
          includeStackTrace: isHigh,
          includeUserFlow: false,
        );
      case LogCategory.system:
      case LogCategory.logic:
        return IncidentSectionSet(
          device: isHigh,
          connectivity: isHigh,
          screen: true,
          network: false,
          custom: true,
          includeStackTrace: isHigh,
          includeUserFlow: true,
        );
    }
  }
}
