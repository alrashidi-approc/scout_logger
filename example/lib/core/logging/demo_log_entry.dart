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
