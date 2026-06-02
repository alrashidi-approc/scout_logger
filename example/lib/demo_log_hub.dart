import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:scout_logger/scout_logger.dart';

class DemoLogEntry {
  const DemoLogEntry({
    required this.channel,
    required this.summary,
    required this.at,
    this.envelope,
    this.batchCount,
    this.metadataPreview,
  });

  final String channel;
  final String summary;
  final DateTime at;
  final LogEnvelope? envelope;
  final int? batchCount;
  final String? metadataPreview;
}

/// Captures batch/emergency handler output for the demo console UI.
class DemoLogHub extends ChangeNotifier {
  DemoLogHub._();
  static final DemoLogHub instance = DemoLogHub._();

  final List<DemoLogEntry> entries = <DemoLogEntry>[];
  bool failNextEmergency = false;
  bool failNextBatch = false;
  int batchUploadCount = 0;
  int emergencyCount = 0;

  void clear() {
    entries.clear();
    batchUploadCount = 0;
    emergencyCount = 0;
    notifyListeners();
  }

  void status(String message) => _push(
        DemoLogEntry(channel: 'status', summary: message, at: DateTime.now()),
      );

  Future<bool> handleBatchJson(List<String> incidents) async {
    final List<LogEnvelope> logs = incidents
        .map((String json) => _previewEnvelope(json))
        .whereType<LogEnvelope>()
        .toList(growable: false);
    return handleBatch(logs, incidentPreviews: incidents);
  }

  Future<void> handleUrgentJson(String incidentJson) async {
    final LogEnvelope? preview = _previewEnvelope(incidentJson);
    if (preview != null) {
      await handleEmergency(preview, incidentPreview: incidentJson);
    }
  }

  LogEnvelope? _previewEnvelope(String incidentJson) {
    try {
      final Map<String, dynamic> map =
          jsonDecode(incidentJson) as Map<String, dynamic>;
      final Map<String, dynamic> event = map['event'] as Map<String, dynamic>;
      return LogEnvelope(
        id: map['incidentId'] as String? ?? 'unknown',
        flavor: (map['app'] as Map<String, dynamic>?)?['flavor'] as String? ?? 'demo',
        domain: Domain.internal,
        category: LogCategory.logic,
        level: LogLevel.error,
        message: event['message'] as String? ?? 'incident',
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> handleBatch(
    List<LogEnvelope> logs, {
    List<String>? incidentPreviews,
  }) async {
    if (failNextBatch) {
      failNextBatch = false;
      status('Batch rejected (${logs.length} logs) — SDK will backoff and retry');
      _push(
        DemoLogEntry(
          channel: 'batch',
          summary: 'FAILED batch (${logs.length})',
          at: DateTime.now(),
          batchCount: logs.length,
        ),
      );
      return false;
    }
    batchUploadCount++;
    final String preview = logs
        .take(3)
        .map((LogEnvelope e) => '${e.level.name}:${e.message}')
        .join(' · ');
    _push(
      DemoLogEntry(
        channel: 'batch',
        summary: 'Batch uploaded (${logs.length} incidents)',
        at: DateTime.now(),
        batchCount: logs.length,
        metadataPreview: incidentPreviews != null && incidentPreviews.isNotEmpty
            ? _shortJson(incidentPreviews.first)
            : (logs.length > 3 ? '$preview · …' : preview),
      ),
    );
    return true;
  }

  String _shortJson(String json) =>
      json.length <= 140 ? json : '${json.substring(0, 140)}…';

  Future<void> handleEmergency(LogEnvelope log, {String? incidentPreview}) async {
    if (failNextEmergency) {
      failNextEmergency = false;
      status('Emergency webhook failed — saved to encrypted urgent queue');
      _push(
        DemoLogEntry(
          channel: 'emergency',
          summary: 'FAILED ${log.level.name}',
          at: DateTime.now(),
          envelope: log,
        ),
      );
      throw StateError('simulated emergency failure');
    }
    emergencyCount++;
    _push(
      DemoLogEntry(
        channel: 'emergency',
        summary: '${log.level.name} dispatched immediately',
        at: DateTime.now(),
        envelope: log,
        metadataPreview: incidentPreview != null
            ? _shortJson(incidentPreview)
            : (log.breadcrumbs.isEmpty
                ? null
                : '${log.breadcrumbs.length} breadcrumbs attached'),
      ),
    );
  }

  void _push(DemoLogEntry entry) {
    entries.insert(0, entry);
    if (entries.length > 80) {
      entries.removeRange(80, entries.length);
    }
    notifyListeners();
  }
}
