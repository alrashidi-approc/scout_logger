import '../core/network_timing_keys.dart';

/// Envelope metadata keys owned by [network.triggering] — omitted from [custom] for NETWORK incidents.
const Set<String> kNetworkIncidentEnvelopeKeys = <String>{
  'traceId',
  'path',
  'method',
  'statusCode',
  'startedAtUs',
  'waterfallUs',
  'waterfallSec',
  'networkWaterfall',
  'networkWaterfallSec',
  'requestHeaders',
  'requestBody',
  'responseBody',
  'headers',
  'body',
  'response',
};

Map<String, dynamic> incidentCustomFromDioExtra(Map<String, dynamic> extra) {
  final dynamic raw = extra[kScoutIncidentCustomKey];
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> envelopeMetadataForCustom({
  required Map<String, dynamic> metadata,
  required bool omitNetworkFields,
}) {
  if (!omitNetworkFields) {
    return metadata;
  }
  return Map<String, dynamic>.from(metadata)
    ..removeWhere((String key, _) => kNetworkIncidentEnvelopeKeys.contains(key));
}
