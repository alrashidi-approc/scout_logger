import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/scout_logger.dart';

void main() {
  test('toIncidentJson without incidentReport is envelope shape not schema 1.2', () {
    final LogEnvelope debugNetwork = LogEnvelope(
      id: '1',
      flavor: 'prod',
      domain: Domain.external,
      category: LogCategory.network,
      level: LogLevel.debug,
      message: 'API request started',
      timestamp: DateTime.parse('2026-06-04T00:00:00.000Z'),
      metadata: <String, dynamic>{'path': '/health'},
    );

    final Map<String, dynamic> json =
        jsonDecode(debugNetwork.toIncidentJson()) as Map<String, dynamic>;
    expect(json.containsKey('schemaVersion'), isFalse);
    expect(json['id'], '1');
    expect(json['metadata'], isNotNull);
  });

  test('blackbox batch should only upload envelopes with incidentReport', () {
    final LogEnvelope debugNetwork = LogEnvelope(
      id: '1',
      flavor: 'prod',
      domain: Domain.external,
      category: LogCategory.network,
      level: LogLevel.debug,
      message: 'API request started',
      timestamp: DateTime.parse('2026-06-04T00:00:00.000Z'),
    );
    final LogEnvelope errorNetwork = LogEnvelope(
      id: '2',
      flavor: 'prod',
      domain: Domain.external,
      category: LogCategory.network,
      level: LogLevel.error,
      message: 'API request failed',
      timestamp: DateTime.parse('2026-06-04T00:00:01.000Z'),
      incidentReport: <String, dynamic>{
        'schemaVersion': kIncidentSchemaVersion,
        'incidentId': '2',
        'event': <String, dynamic>{'level': 'ERROR'},
      },
    );

    final List<String> payloads = <String>[
      for (final LogEnvelope log in <LogEnvelope>[debugNetwork, errorNetwork])
        if (log.incidentReport != null) log.toIncidentJson(),
    ];

    expect(payloads, hasLength(1));
    expect(
      (jsonDecode(payloads.single) as Map)['schemaVersion'],
      kIncidentSchemaVersion,
    );
  });
}
