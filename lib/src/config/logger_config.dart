import '../models/log_models.dart';

typedef BulkUploadHandler = Future<bool> Function(List<LogEnvelope> logs);
typedef EmergencyWebhookHandler = Future<void> Function(LogEnvelope log);
typedef RuntimeVitalsProbe = Future<Map<String, dynamic>> Function();

class ScoutLoggerConfig {
  const ScoutLoggerConfig({
    required this.flavor,
    required this.bulkUploadHandler,
    required this.emergencyWebhookHandler,
    this.encryptionKey = 'scout_logger_default_key',
    this.batchSize = 50,
    this.batchWindow = const Duration(seconds: 120),
    this.wifiOnlySync = false,
    this.breadcrumbLimit = 50,
    this.minimumLevel = LogLevel.info,
    this.runtimeVitalsProbe,
  });

  final String flavor;
  final BulkUploadHandler bulkUploadHandler;
  final EmergencyWebhookHandler emergencyWebhookHandler;
  final String encryptionKey;
  final int batchSize;
  final Duration batchWindow;
  final bool wifiOnlySync;
  final int breadcrumbLimit;
  final LogLevel minimumLevel;
  final RuntimeVitalsProbe? runtimeVitalsProbe;
}
