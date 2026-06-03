/// Readable UTC + local timestamps for incident JSON.
Map<String, dynamic> formatIncidentTime(DateTime at) {
  final DateTime utc = at.toUtc();
  final DateTime local = at.toLocal();
  final Duration offset = local.timeZoneOffset;
  return <String, dynamic>{
    'utc': _iso(utc),
    'local': _iso(local),
    'localOffsetMinutes': offset.inMinutes,
    'epochMs': at.millisecondsSinceEpoch,
  };
}

String _iso(DateTime value) => value.toIso8601String();

/// Adds human-readable second-based durations alongside microsecond fields.
Map<String, dynamic> normalizeDurationsInMap(Map<String, dynamic> source) {
  final Map<String, dynamic> out = Map<String, dynamic>.from(source);
  final Object? waterfallUs = out['waterfallUs'];
  if (waterfallUs is Map) {
    out['waterfallUs'] = Map<String, dynamic>.from(waterfallUs);
    out['waterfallSec'] = _waterfallUsToSec(waterfallUs);
  }
  final Object? networkWaterfall = out['networkWaterfall'];
  if (networkWaterfall is List) {
    out['networkWaterfall'] = networkWaterfall;
    out['networkWaterfallSec'] = _networkWaterfallToSec(networkWaterfall);
  }
  if (out.containsKey('startedAtUs')) {
    out['startedAtSec'] = _usToSec(out['startedAtUs']);
  }
  if (out.containsKey('ttfb') && out['ttfb'] is num) {
    out['ttfbSec'] = _usToSec(out['ttfb']);
  }
  if (out.containsKey('total') && out['total'] is num) {
    out['totalSec'] = _usToSec(out['total']);
  }
  return out;
}

Map<String, dynamic>? _waterfallUsToSec(Map<dynamic, dynamic> waterfallUs) {
  final Map<String, dynamic> sec = <String, dynamic>{};
  for (final MapEntry<dynamic, dynamic> entry in waterfallUs.entries) {
    if (entry.value is num) {
      sec[entry.key.toString()] = _usToSec(entry.value);
    }
  }
  return sec.isEmpty ? null : sec;
}

List<Map<String, dynamic>>? _networkWaterfallToSec(List<dynamic> phases) {
  final List<Map<String, dynamic>> sec = <Map<String, dynamic>>[];
  for (final dynamic phase in phases) {
    if (phase is Map) {
      final Object? durationUs = phase['durationUs'];
      sec.add(<String, dynamic>{
        'phase': phase['phase'],
        if (durationUs is num) 'durationUs': durationUs,
        if (durationUs is num) 'durationSec': _usToSec(durationUs),
      });
    }
  }
  return sec.isEmpty ? null : sec;
}

double? _usToSec(Object? micros) {
  if (micros is! num) {
    return null;
  }
  return double.parse((micros / 1000000).toStringAsFixed(3));
}
