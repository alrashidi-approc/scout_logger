import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/reporting/incident_email_formatter.dart';

void main() {
  test('formats readable email body with key sections', () {
    final String body = formatIncidentEmailBody(<String, dynamic>{
      'incidentId': '1',
      'timestamp': '2026-06-02T12:00:00Z',
      'event': <String, dynamic>{
        'level': 'ERROR',
        'category': 'NETWORK',
        'message': 'Payment failed',
        'stackTrace': 'Error at line 1',
      },
      'app': <String, dynamic>{
        'packageName': 'com.test',
        'version': '1.0',
        'buildNumber': '1',
        'flavor': 'production',
        'sdkVersion': '1.0.0',
        'platform': 'android',
      },
      'user': <String, dynamic>{'userId': 'u1'},
      'device': <String, dynamic>{
        'manufacturer': 'Google',
        'deviceModel': 'Pixel',
        'osVersion': '14',
        'ramUsedBytes': 1,
      },
      'connectivity': <String, dynamic>{'isOnline': true, 'types': <String>['wifi']},
      'screen': <String, dynamic>{
        'currentRoute': '/pay',
        'userFlow': <Map<String, dynamic>>[],
      },
      'network': <String, dynamic>{
        'triggering': <String, dynamic>{'method': 'POST', 'path': '/pay', 'traceId': 't1'},
        'recent': <Map<String, dynamic>>[],
      },
    });

    expect(body, contains('What happened'));
    expect(body, contains('Payment failed'));
    expect(body, contains('u1'));
    expect(body, contains('Stack (truncated)'));
  });

  test('rollup subject shows occurrence multiplier', () {
    final String subject = formatIncidentEmailSubject(<String, dynamic>{
      'event': <String, dynamic>{'level': 'FATAL', 'message': 'Crash'},
      'app': <String, dynamic>{'packageName': 'com.test'},
      'triage': <String, dynamic>{
        'occurrence': <String, dynamic>{'count': 12},
      },
    }, '[Alert]');

    expect(subject, contains('×12'));
    expect(subject, contains('Crash'));
  });
}
