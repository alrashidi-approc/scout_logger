const String kScoutStartUsKey = 'scout_logger_start_us';
const String kScoutFirstByteUsKey = 'scout_logger_first_byte_us';
const String kScoutResponseDoneUsKey = 'scout_logger_response_done_us';
const String kScoutTraceIdKey = 'scout_logger_trace_id';

/// Per-request app fields for incident `custom` (not copied to `network.triggering`).
///
/// ```dart
/// options.extra[kScoutIncidentCustomKey] = {'feature': 'inbox'};
/// ```
const String kScoutIncidentCustomKey = 'scout_logger_incident_custom';
