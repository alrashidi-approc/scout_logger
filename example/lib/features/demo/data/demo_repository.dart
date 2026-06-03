import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:scout_logger/scout_logger.dart';

import '../../../core/logging/demo_log_hub.dart';
import '../../../core/network/api_client.dart';

/// Demo use-cases: network, logging, batch, remote level (repository layer).
class DemoRepository {
  DemoRepository({
    required ScoutLogger logger,
    required ApiClient apiClient,
    required DemoLogHub hub,
  })  : _logger = logger,
        _dio = apiClient.dio,
        _hub = hub;

  final ScoutLogger _logger;
  final Dio _dio;
  final DemoLogHub _hub;

  ScoutLogger get logger => _logger;
  DemoLogHub get hub => _hub;

  Future<void> runNavigationFlow(BuildContext context) async {
    _logger.navigatorObserver.addManualBreadcrumb(
      'DEMO_TAP',
      metadata: <String, dynamic>{'screen': 'home'},
    );
    final NavigatorState nav = Navigator.of(context);
    await nav.pushNamed('/details');
    await nav.pushNamed('/checkout');
    nav.popUntil((Route<dynamic> r) => r.isFirst);
    _hub.status('Navigation flow complete — breadcrumbs recorded');
  }

  Future<void> networkSuccess() async {
    _hub.status('GET /get — 200 OK (not logged: errorsOnly)');
    await _dio.get<dynamic>('https://httpbin.org/get');
    _hub.status('Done — no network log expected in console');
  }

  Future<void> networkServerError() async {
    _hub.status('GET /status/503 — should log API request failed');
    try {
      await _dio.get<dynamic>('https://httpbin.org/status/503');
    } on DioException {
      _hub.status('503 logged as failure → batch when queue fills');
    }
  }

  Future<void> networkIgnored401() async {
    _hub.status('GET /status/401 — ignored (nonErrorStatusCodes)');
    try {
      await _dio.get<dynamic>('https://httpbin.org/status/401');
    } on DioException {
      _hub.status('Done — no network log expected for 401');
    }
  }

  Future<void> networkPiiScrubDemo() async {
    _hub.status('POST with password/token — logged only on failure path');
    try {
      await _dio.post<dynamic>(
        'https://httpbin.org/post',
        data: <String, dynamic>{
          'email': 'user@example.com',
          'password': 'secret123',
          'token': 'abc',
        },
      );
    } on DioException {
      // Demo may succeed (200) — no failure log in errorsOnly mode.
    }
  }

  Future<void> fillBatch() async {
    _hub.status('Enqueueing 6 INFO logs (batch size = 5) …');
    for (int i = 0; i < 6; i++) {
    await _logger.info(
      'demo batch item $i',
      metadata: <String, dynamic>{'index': i},
    );
    }
  }

  Future<void> logSimulatedError() async {
    _logger.setTag('feature', 'checkout');
    _logger.setContext('order', <String, dynamic>{'step': 'payment'});
    await _logger.error(
      'Simulated checkout failure',
      metadata: <String, dynamic>{'step': 'payment'},
      stackTrace: StackTrace.current.toString(),
    );
  }

  Future<void> logSimulatedFatal() async {
    await _logger.fatal(
      'Simulated fatal — bypasses batch queue',
      stackTrace: StackTrace.current.toString(),
    );
  }

  void armFailNextUrgent() => _hub.failNextEmergency = true;

  void armFailNextBatch() {
    _hub.failNextBatch = true;
    _hub.status('Next batch upload will fail (then retry)');
  }

  Future<void> setRemoteMinLevel(LogLevel level) async {
    await _logger.updateLogLevelsRemote(minimumLevel: level);
    _hub.status('Remote min level → ${level.name.toUpperCase()}');
  }
}
