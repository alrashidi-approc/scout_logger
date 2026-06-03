import '../models/log_models.dart';

typedef BulkUploadHandler = Future<bool> Function(List<LogEnvelope> logs);
typedef EmergencyWebhookHandler = Future<void> Function(LogEnvelope log);
typedef BlackboxBulkUploadHandler = Future<bool> Function(List<String> incidents);
typedef BlackboxEmergencyHandler = Future<void> Function(String incidentJson);
typedef BlackboxSingleUploadHandler = Future<bool> Function(String incidentJson);
