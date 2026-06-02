import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/log_models.dart';
import 'scout_logger_manager.dart';

typedef CrashLogEmitter =
    Future<void> Function({
      required Domain domain,
      required LogCategory category,
      required LogLevel level,
      required String message,
      Map<String, dynamic> metadata,
      String? stackTrace,
      bool immediateDispatch,
    });

class CrashHooks {
  CrashHooks.fromLogger(ScoutLogger logger, {DateTime Function()? nowProvider})
    : this(logger.log, nowProvider: nowProvider);

  CrashHooks(this._emitCrashLog, {DateTime Function()? nowProvider})
    : _now = nowProvider ?? DateTime.now;

  final CrashLogEmitter _emitCrashLog;
  final DateTime Function() _now;
  FlutterExceptionHandler? _previousFlutterOnError;
  ErrorCallback? _previousPlatformOnError;
  DateTime? _lastCrashAt;
  String? _lastCrashSignature;
  static const Duration _dedupeWindow = Duration(seconds: 2);

  void install() {
    _previousFlutterOnError = FlutterError.onError;
    _previousPlatformOnError = PlatformDispatcher.instance.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      unawaited(
        _recordCrash(
          message: details.exceptionAsString(),
          stackTrace: details.stack?.toString(),
        ),
      );
      _previousFlutterOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
      unawaited(
        _recordCrash(message: error.toString(), stackTrace: stackTrace.toString()),
      );
      return _previousPlatformOnError?.call(error, stackTrace) ?? false;
    };
  }

  void uninstall() {
    FlutterError.onError = _previousFlutterOnError;
    PlatformDispatcher.instance.onError = _previousPlatformOnError;
  }

  @visibleForTesting
  Future<void> recordForTest({
    required String message,
    required String stackTrace,
  }) =>
      _recordCrash(message: message, stackTrace: stackTrace);

  Future<void> _recordCrash({
    required String message,
    required String? stackTrace,
  }) async {
    final String signature = '$message|$stackTrace';
    if (_isDuplicate(signature)) {
      return;
    }
    _lastCrashSignature = signature;
    _lastCrashAt = _now();
    try {
      await _emitCrashLog(
        domain: Domain.internal,
        category: LogCategory.systemCrash,
        level: LogLevel.fatal,
        message: message,
        stackTrace: stackTrace,
        immediateDispatch: true,
      );
    } catch (_) {
      // Never throw from crash handlers.
    }
  }

  bool _isDuplicate(String signature) {
    final DateTime? lastAt = _lastCrashAt;
    if (lastAt == null || _lastCrashSignature != signature) {
      return false;
    }
    return _now().difference(lastAt) <= _dedupeWindow;
  }
}
