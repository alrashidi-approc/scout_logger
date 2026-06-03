import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/product_insights_policy.dart';
import 'package:scout_logger/src/core/connectivity_snapshot.dart';
import 'package:scout_logger/src/models/incident_report.dart';
import 'package:scout_logger/src/models/log_models.dart';

import 'test_helpers.dart';

void main() {
  test('incident includes triage and deployment blocks', () {
    final Map<String, dynamic> report = buildIncidentReport(
      envelope: LogEnvelope(
        id: 'x1',
        flavor: 'production',
        domain: Domain.internal,
        category: LogCategory.logic,
        level: LogLevel.error,
        message: 'checkout failed',
        timestamp: DateTime.parse('2026-06-03T12:00:00Z'),
        stackTrace: 'Error at checkout.dart:10',
      ),
      app: kTestAppContext,
      flavor: 'production',
      tags: <String, String>{'feature': 'checkout'},
      contexts: <String, Map<String, dynamic>>{
        'cart': <String, dynamic>{'id': 'c1'},
      },
      release: 'com.app@2.0.0+42',
      environment: 'production',
      sessionStartedAt: DateTime.parse('2026-06-03T11:00:00Z'),
      sessionIncidentIndex: 3,
    );

    expect(report['schemaVersion'], '1.2');
    expect((report['triage'] as Map)['groupingKey'], isNotEmpty);
    expect((report['triage'] as Map)['fingerprint'], isNotEmpty);
    expect((report['triage'] as Map)['tags'], containsPair('feature', 'checkout'));
    expect((report['deployment'] as Map)['release'], 'com.app@2.0.0+42');
    expect((report['session'] as Map)['incidentIndex'], 3);
  });

  test('beforeIncidentSend can drop incident', () {
    const ProductInsightsPolicy policy = ProductInsightsPolicy(
      beforeIncidentSend: _dropAll,
    );
    final Map<String, dynamic> raw = buildIncidentReport(
      envelope: LogEnvelope(
        id: 'x2',
        flavor: 'test',
        domain: Domain.internal,
        category: LogCategory.logic,
        level: LogLevel.error,
        message: 'drop me',
        timestamp: DateTime.now(),
      ),
      app: kTestAppContext,
      flavor: 'test',
      connectivity: const ConnectivitySnapshot(types: <String>['wifi'], isOnline: true),
    );
    expect(policy.beforeIncidentSend!(raw), isNull);
  });
}

Map<String, dynamic>? _dropAll(Map<String, dynamic> incident) => null;
