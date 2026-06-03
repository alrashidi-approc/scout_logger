import '../models/log_models.dart';
import 'upload_handlers.dart';

/// Route logs to different backend endpoints (e.g. network microservice vs crash service).
class LogServerRouting {
  const LogServerRouting({
    required this.defaultBulk,
    this.networkBulk,
    this.crashBulk,
    this.uiBulk,
    this.defaultUrgent,
    this.networkUrgent,
    this.crashUrgent,
  });

  final BulkUploadHandler defaultBulk;
  final BulkUploadHandler? networkBulk;
  final BulkUploadHandler? crashBulk;
  final BulkUploadHandler? uiBulk;
  final EmergencyWebhookHandler? defaultUrgent;
  final EmergencyWebhookHandler? networkUrgent;
  final EmergencyWebhookHandler? crashUrgent;

  BulkUploadHandler bulkFor(LogCategory category) {
    switch (category) {
      case LogCategory.network:
        return networkBulk ?? defaultBulk;
      case LogCategory.systemCrash:
        return crashBulk ?? defaultBulk;
      case LogCategory.ui:
        return uiBulk ?? defaultBulk;
      case LogCategory.secureStorage:
      case LogCategory.system:
      case LogCategory.logic:
        return defaultBulk;
    }
  }

  EmergencyWebhookHandler? urgentFor(LogCategory category) {
    switch (category) {
      case LogCategory.network:
        return networkUrgent ?? defaultUrgent;
      case LogCategory.systemCrash:
        return crashUrgent ?? defaultUrgent;
      case LogCategory.ui:
      case LogCategory.secureStorage:
      case LogCategory.system:
      case LogCategory.logic:
        return defaultUrgent;
    }
  }
}
