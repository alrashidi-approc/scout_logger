import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/blackbox_app_context.dart';
import 'package:scout_logger/src/config/incident_sharing_policy.dart';
import 'package:scout_logger/src/models/incident_report.dart';
import 'package:scout_logger/src/models/log_models.dart';

void main() {
  test('minimal policy nulls heavy sections but keeps keys', () {
    final Map<String, dynamic> report = buildIncidentReport(
      envelope: _envelope(LogCategory.network),
      app: kApp,
      flavor: 'production',
      sharingPolicy: const IncidentSharingPolicy(
        defaultLevel: IncidentDetailLevel.minimal,
      ),
    );
    expect(report['device'], isNull);
    expect(report['network'], isNull);
    expect(report['screen'], isNull);
    expect(report['event'], isNotNull);
    expect(report['payload'], isNotNull);
  });

  test('focused network includes network but can omit device on warn', () {
    final Map<String, dynamic> report = buildIncidentReport(
      envelope: _envelope(LogCategory.network, level: LogLevel.warn),
      app: kApp,
      flavor: 'production',
      sharingPolicy: const IncidentSharingPolicy(),
    );
    expect(report['network'], isNotNull);
    expect(report['device'], isNull);
  });

  test('fatal uses full payload by default', () {
    final IncidentSectionSet sections = const IncidentSharingPolicy().resolveSections(
      LogLevel.fatal,
      LogCategory.logic,
    );
    expect(sections.device, isTrue);
    expect(sections.network, isTrue);
  });
}

const BlackboxAppContext kApp = BlackboxAppContext(
  appVersion: '1',
  buildNumber: '1',
  packageName: 'com.test',
  userId: 'u1',
  userMetadata: <String, dynamic>{'tenant': 'kw'},
);

LogEnvelope _envelope(LogCategory category, {LogLevel level = LogLevel.error}) =>
    LogEnvelope(
      id: '1',
      flavor: 'production',
      domain: Domain.external,
      category: category,
      level: level,
      message: 'test',
      timestamp: DateTime.parse('2026-06-02T12:00:00.000Z'),
      metadata: <String, dynamic>{
        'waterfallUs': <String, int>{'ttfb': 1200000, 'total': 5000000},
      },
    );
