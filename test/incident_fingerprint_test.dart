import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/models/log_models.dart';
import 'package:scout_logger/src/util/incident_fingerprint.dart';

void main() {
  test('groupingKey is stable for same message and stack', () {
    const String stack = 'DioException: 503\nat pay.dart:42';
    final String a = computeGroupingKey(
      message: 'Payment failed',
      stackTrace: stack,
      fingerprint: buildFingerprint(
        category: LogCategory.logic,
        message: 'Payment failed',
        stackTrace: stack,
      ),
    );
    final String b = computeGroupingKey(
      message: 'Payment failed',
      stackTrace: stack,
      fingerprint: buildFingerprint(
        category: LogCategory.logic,
        message: 'Payment failed',
        stackTrace: stack,
      ),
    );
    expect(a, b);
  });

  test('fingerprint includes tags', () {
    final List<String> parts = buildFingerprint(
      category: LogCategory.network,
      message: 'API failed',
      tags: <String, String>{'feature': 'checkout'},
    );
    expect(parts, contains('feature:checkout'));
  });
}
