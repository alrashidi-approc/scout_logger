import '../models/log_models.dart';
import 'scout_logger_manager.dart';

/// Shortcuts for common log calls (defaults: internal + logic).
extension ScoutLoggerSimpleLog on ScoutLogger {
  Future<void> debug(
    String message, {
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> customMetadata = const <String, dynamic>{},
    LogCategory category = LogCategory.logic,
  }) =>
      log(
        domain: Domain.internal,
        category: category,
        level: LogLevel.debug,
        message: message,
        metadata: metadata,
        customMetadata: customMetadata,
      );

  Future<void> info(
    String message, {
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> customMetadata = const <String, dynamic>{},
    LogCategory category = LogCategory.logic,
  }) =>
      log(
        domain: Domain.internal,
        category: category,
        level: LogLevel.info,
        message: message,
        metadata: metadata,
        customMetadata: customMetadata,
      );

  Future<void> warn(
    String message, {
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> customMetadata = const <String, dynamic>{},
    String? stackTrace,
    LogCategory category = LogCategory.logic,
  }) =>
      log(
        domain: Domain.internal,
        category: category,
        level: LogLevel.warn,
        message: message,
        metadata: metadata,
        customMetadata: customMetadata,
        stackTrace: stackTrace,
      );

  Future<void> error(
    String message, {
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> customMetadata = const <String, dynamic>{},
    String? stackTrace,
    LogCategory category = LogCategory.logic,
  }) =>
      log(
        domain: Domain.internal,
        category: category,
        level: LogLevel.error,
        message: message,
        metadata: metadata,
        customMetadata: customMetadata,
        stackTrace: stackTrace,
      );

  Future<void> fatal(
    String message, {
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> customMetadata = const <String, dynamic>{},
    String? stackTrace,
    LogCategory category = LogCategory.systemCrash,
  }) =>
      log(
        domain: Domain.internal,
        category: category,
        level: LogLevel.fatal,
        message: message,
        metadata: metadata,
        customMetadata: customMetadata,
        stackTrace: stackTrace,
      );

  Future<void> critical(
    String message, {
    Map<String, dynamic> metadata = const <String, dynamic>{},
    Map<String, dynamic> customMetadata = const <String, dynamic>{},
    String? stackTrace,
    LogCategory category = LogCategory.logic,
  }) =>
      log(
        domain: Domain.internal,
        category: category,
        level: LogLevel.critical,
        message: message,
        metadata: metadata,
        customMetadata: customMetadata,
        stackTrace: stackTrace,
      );
}

/// Facade shortcuts — use after [ScoutAppLogger.init].
abstract final class ScoutAppLoggerSimpleLog {
  ScoutAppLoggerSimpleLog._();

  static Future<void> debug(String message, {Map<String, dynamic> metadata = const {}}) =>
      ScoutLogger.instance.debug(message, metadata: metadata);

  static Future<void> info(String message, {Map<String, dynamic> metadata = const {}}) =>
      ScoutLogger.instance.info(message, metadata: metadata);

  static Future<void> warn(String message, {Map<String, dynamic> metadata = const {}, String? stackTrace}) =>
      ScoutLogger.instance.warn(message, metadata: metadata, stackTrace: stackTrace);

  static Future<void> error(String message, {Map<String, dynamic> metadata = const {}, String? stackTrace}) =>
      ScoutLogger.instance.error(message, metadata: metadata, stackTrace: stackTrace);

  static Future<void> fatal(String message, {Map<String, dynamic> metadata = const {}, String? stackTrace}) =>
      ScoutLogger.instance.fatal(message, metadata: metadata, stackTrace: stackTrace);

  static Future<void> critical(String message, {Map<String, dynamic> metadata = const {}, String? stackTrace}) =>
      ScoutLogger.instance.critical(message, metadata: metadata, stackTrace: stackTrace);
}
