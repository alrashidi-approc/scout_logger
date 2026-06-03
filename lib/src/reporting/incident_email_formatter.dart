/// Plain-text incident alert for email (short, not a log dump).
String formatIncidentEmailBody(
  Map<String, dynamic> incident, {
  int maxBreadcrumbs = 5,
  int maxStackTraceLines = 12,
}) {
  final Map<String, dynamic> event =
      incident['event'] as Map<String, dynamic>? ?? <String, dynamic>{};
  final Map<String, dynamic> app =
      incident['app'] as Map<String, dynamic>? ?? <String, dynamic>{};
  final Map<String, dynamic> user =
      incident['user'] as Map<String, dynamic>? ?? <String, dynamic>{};
  final Map<String, dynamic> triage =
      incident['triage'] as Map<String, dynamic>? ?? <String, dynamic>{};
  final Map<String, dynamic>? occurrence =
      triage['occurrence'] as Map<String, dynamic>?;
  final Map<String, dynamic> screen =
      incident['screen'] as Map<String, dynamic>? ?? <String, dynamic>{};
  final Map<String, dynamic> network =
      incident['network'] as Map<String, dynamic>? ?? <String, dynamic>{};

  final int count = occurrence?['count'] as int? ?? 1;
  final bool isRollup = occurrence?['reportReason'] == 'rollup';
  final int sinceLast = occurrence?['sinceLastReport'] as int? ?? count;

  final StringBuffer body = StringBuffer();
  if (count > 1) {
    body.writeln(
      isRollup
          ? 'REPEAT ALERT — this issue occurred $sinceLast more time(s) ($count total this session).'
          : 'NEW ISSUE — first occurrence (will group repeats by fingerprint).',
    );
    body.writeln();
  }

  body
    ..writeln('What happened')
    ..writeln('--------------')
    ..writeln('${event['level']} · ${event['category']}')
    ..writeln(event['message'])
    ..writeln()
    ..writeln('Where')
    ..writeln('-----')
    ..writeln('App     : ${app['name'] ?? app['packageName']} ${app['version']} (${app['flavor']})')
    ..writeln('Screen  : ${screen['currentRoute'] ?? '—'}')
    ..writeln('User    : ${user['userId'] ?? '—'}')
    ..writeln('Time    : ${_timeLocal(incident)} (${_timeUtc(incident)} UTC)');

  final String? groupingKey = triage['groupingKey'] as String?;
  if (groupingKey != null) {
    body.writeln('Group   : $groupingKey');
  }
  if (occurrence != null) {
    body
      ..writeln('Count   : $count')
      ..writeln('First   : ${occurrence['firstSeenAt'] ?? '—'}')
      ..writeln('Last    : ${occurrence['lastSeenAt'] ?? '—'}');
  }
  body.writeln();

  final List<dynamic> flow = screen['userFlow'] as List<dynamic>? ?? <dynamic>[];
  if (flow.isNotEmpty) {
    body.writeln('Last steps (max $maxBreadcrumbs)');
    body.writeln('---------------------------');
    final int start = flow.length > maxBreadcrumbs ? flow.length - maxBreadcrumbs : 0;
    for (int i = start; i < flow.length; i++) {
      final dynamic step = flow[i];
      if (step is Map) {
        body.writeln('  • ${step['label']}');
      }
    }
    body.writeln();
  }

  final Map<String, dynamic>? triggering =
      network['triggering'] as Map<String, dynamic>?;
  if (triggering != null && triggering.isNotEmpty) {
    body
      ..writeln('API')
      ..writeln('---')
      ..writeln(
        '${triggering['method']} ${triggering['path']} → ${triggering['statusCode']}',
      )
      ..writeln('Trace: ${triggering['traceId'] ?? '—'}')
      ..writeln();
  }

  final String? stack = event['stackTrace'] as String?;
  if (stack != null && stack.isNotEmpty && !isRollup) {
    body
      ..writeln('Stack (truncated)')
      ..writeln('-----------------')
      ..writeln(_truncateStack(stack, maxStackTraceLines))
      ..writeln();
  } else if (isRollup) {
    body.writeln('Stack trace omitted on repeat alert — see first report or backend.');
    body.writeln();
  }

  body.writeln('Incident ID: ${incident['incidentId']}');
  body.writeln('— Scout App Logger');
  return body.toString();
}

String _truncateStack(String stack, int maxLines) {
  final List<String> lines = stack.split('\n');
  if (lines.length <= maxLines) {
    return stack;
  }
  final List<String> head = lines.take(maxLines).toList();
  head.add('… (${lines.length - maxLines} more lines)');
  return head.join('\n');
}

String _timeUtc(Map<String, dynamic> incident) {
  final Map<String, dynamic>? time = incident['time'] as Map<String, dynamic>?;
  return time?['utc'] as String? ?? incident['timestamp'] as String? ?? '—';
}

String _timeLocal(Map<String, dynamic> incident) {
  final Map<String, dynamic>? time = incident['time'] as Map<String, dynamic>?;
  return time?['local'] as String? ?? '—';
}

String formatIncidentEmailSubject(
  Map<String, dynamic> incident,
  String prefix,
) {
  final Map<String, dynamic> event =
      incident['event'] as Map<String, dynamic>? ?? <String, dynamic>{};
  final Map<String, dynamic> app =
      incident['app'] as Map<String, dynamic>? ?? <String, dynamic>{};
  final Map<String, dynamic> triage =
      incident['triage'] as Map<String, dynamic>? ?? <String, dynamic>{};
  final Map<String, dynamic>? occurrence =
      triage['occurrence'] as Map<String, dynamic>?;
  final int count = occurrence?['count'] as int? ?? 1;
  final String level = '${event['level']}';
  final String message = '${event['message']}';
  final String pkg = '${app['name'] ?? app['packageName']}';
  if (count > 1) {
    return '$prefix ×$count $level · $pkg · $message';
  }
  return '$prefix $level · $pkg · $message';
}
