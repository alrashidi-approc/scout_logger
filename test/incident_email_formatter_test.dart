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
        'sdkVersion': '0.0.1',
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

    expect(body, contains('MOBILE INCIDENT REPORT'));
    expect(body, contains('Payment failed'));
    expect(body, contains('User ID'));
    expect(body, contains('u1'));
    expect(body, contains('Stack trace'));
  });
}
