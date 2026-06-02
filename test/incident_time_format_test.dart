import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/util/incident_time_format.dart';

void main() {
  test('formatIncidentTime exposes utc and local', () {
    final Map<String, dynamic> time = formatIncidentTime(
      DateTime.utc(2026, 6, 2, 12, 0, 0),
    );
    expect(time['utc'], '2026-06-02T12:00:00.000Z');
    expect(time['local'], isNotNull);
    expect(time['epochMs'], isA<int>());
  });

  test('normalizeDurationsInMap adds waterfallSec', () {
    final Map<String, dynamic> out = normalizeDurationsInMap(<String, dynamic>{
      'waterfallUs': <String, int>{'ttfb': 1500000, 'total': 3000000},
    });
    expect(out['waterfallSec'], <String, dynamic>{
      'ttfb': 1.5,
      'total': 3.0,
    });
  });
}
