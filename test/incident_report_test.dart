import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/blackbox_app_context.dart';
import 'package:scout_logger/src/core/connectivity_snapshot.dart';
import 'package:scout_logger/src/models/incident_report.dart';
import 'package:scout_logger/src/models/log_models.dart';

void main() {
  test('builds single incident JSON with user flow and API context', () {
    final LogEnvelope envelope = LogEnvelope(
      id: 'inc-1',
      flavor: 'production',
      domain: Domain.external,
      category: LogCategory.network,
      level: LogLevel.error,
      message: 'API request failed',
      timestamp: DateTime.parse('2026-06-02T12:00:00.000Z'),
      stackTrace: 'DioException: 503',
      metadata: <String, dynamic>{
        'traceId': 'trace-abc',
        'path': '/pay',
        'method': 'POST',
        'statusCode': 503,
        'waterfallUs': <String, int>{'ttfb': 1000000, 'total': 2000000},
      },
      breadcrumbs: <Breadcrumb>[
        Breadcrumb(
          label: 'NAV_PUSH',
          timestamp: DateTime.parse('2026-06-02T11:59:50.000Z'),
          metadata: <String, dynamic>{'to': '/checkout'},
        ),
      ],
      deviceVitals: const DeviceVitalsSnapshot(
        osVersion: '17',
        deviceModel: 'Pixel',
        manufacturer: 'Google',
        ramUsedBytes: 100,
        batteryLevel: 42,
      ),
    );

    const BlackboxAppContext app = BlackboxAppContext(
      appVersion: '2.0.0',
      buildNumber: '42',
      packageName: 'com.example.shop',
      appName: 'Example Shop',
      userId: 'u-99',
      sessionId: 'sess-1',
      globalMetadata: <String, dynamic>{'tenant': 'kw'},
    );

    final Map<String, dynamic> report = buildIncidentReport(
      envelope: envelope,
      app: app,
      flavor: 'production',
      connectivity: const ConnectivitySnapshot(types: <String>['wifi'], isOnline: true),
      recentNetwork: <Map<String, dynamic>>[
        <String, dynamic>{'path': '/cart', 'statusCode': 200},
      ],
      currentRoute: '/checkout',
    );

    expect(report['schemaVersion'], kIncidentSchemaVersion);
    expect(report['incidentId'], 'inc-1');
    expect((report['time'] as Map)['utc'], isNotNull);
    expect(report['app'], containsPair('version', '2.0.0'));
    expect(report['app'], containsPair('name', 'Example Shop'));
    expect((report['deployment'] as Map)['appName'], 'Example Shop');
    expect(report['user'], containsPair('userId', 'u-99'));
    expect((report['network'] as Map)['triggering'], contains('waterfallSec'));
    expect(report['screen'], containsPair('currentRoute', '/checkout'));
    expect((report['screen'] as Map)['userFlow'], hasLength(1));
    expect((report['network'] as Map)['triggering'], containsPair('traceId', 'trace-abc'));
    expect(report['custom'], containsPair('tenant', 'kw'));
    expect((report['custom'] as Map).containsKey('traceId'), isFalse);
    expect((report['custom'] as Map).containsKey('path'), isFalse);
    expect(incidentReportToJson(report), contains('trace-abc'));
  });

  test('network incident merges explicit customMetadata without network dupes', () {
    final LogEnvelope envelope = LogEnvelope(
      id: 'inc-3',
      flavor: 'production',
      domain: Domain.external,
      category: LogCategory.network,
      level: LogLevel.error,
      message: 'API request failed',
      timestamp: DateTime.parse('2026-06-02T12:00:00.000Z'),
      metadata: <String, dynamic>{
        'traceId': 't-1',
        'path': '/inbox',
        'method': 'GET',
        'statusCode': 404,
      },
      incidentCustom: <String, dynamic>{'feature': 'inbox', 'userId': '9898'},
    );

    const BlackboxAppContext app = BlackboxAppContext(
      appVersion: '1.0.0',
      buildNumber: '1',
      packageName: 'com.test',
    );

    final Map<String, dynamic> report = buildIncidentReport(
      envelope: envelope,
      app: app,
      flavor: 'production',
    );

    expect((report['custom'] as Map)['feature'], 'inbox');
    expect((report['custom'] as Map).containsKey('path'), isFalse);
    expect((report['network'] as Map)['triggering'], containsPair('path', '/inbox'));
  });

  test('custom keeps envelope metadata for non-network incidents', () {
    final LogEnvelope envelope = LogEnvelope(
      id: 'inc-2',
      flavor: 'production',
      domain: Domain.internal,
      category: LogCategory.logic,
      level: LogLevel.error,
      message: 'Payment failed',
      timestamp: DateTime.parse('2026-06-02T12:00:00.000Z'),
      metadata: <String, dynamic>{'orderId': 'ord_1', 'traceId': 't-1'},
    );

    const BlackboxAppContext app = BlackboxAppContext(
      appVersion: '1.0.0',
      buildNumber: '1',
      packageName: 'com.test',
    );

    final Map<String, dynamic> report = buildIncidentReport(
      envelope: envelope,
      app: app,
      flavor: 'production',
    );

    expect((report['custom'] as Map)['orderId'], 'ord_1');
    expect((report['custom'] as Map)['traceId'], 't-1');
  });
}
