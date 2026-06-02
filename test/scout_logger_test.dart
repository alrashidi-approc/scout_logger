import 'package:flutter_test/flutter_test.dart';

import 'package:scout_logger/scout_logger.dart';

void main() {
  test('serializes log envelope with expected tags', () {
    final envelope = LogEnvelope(
      id: '1',
      flavor: 'production',
      domain: Domain.internal,
      category: LogCategory.systemCrash,
      level: LogLevel.fatal,
      message: 'boom',
      timestamp: DateTime.parse('2026-06-02T00:00:00.000Z'),
    );

    final json = envelope.toJson();
    expect(json['domain'], 'INTERNAL');
    expect(json['category'], 'SYSTEM_CRASH');
    expect(json['level'], 'FATAL');
  });

  test('exposes ScoutAppLogger facade', () {
    expect(() => ScoutAppLogger.instance, throwsStateError);
  });
}
