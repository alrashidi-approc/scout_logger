import 'package:scout_logger/src/config/blackbox_app_context.dart';
import 'package:scout_logger/src/config/logger_config.dart';
import 'package:scout_logger/src/models/log_models.dart';

const BlackboxAppContext kTestAppContext = BlackboxAppContext(
  appVersion: '1.0.0',
  buildNumber: '1',
  packageName: 'com.scout_logger.test',
  userId: 'test-user',
  sessionId: 'test-session',
);

ScoutLoggerConfig testLoggerConfig({
  required BulkUploadHandler bulkUploadHandler,
  required EmergencyWebhookHandler emergencyWebhookHandler,
}) {
  return ScoutLoggerConfig(
    flavor: 'test',
    appContext: kTestAppContext,
    bulkUploadHandler: bulkUploadHandler,
    emergencyWebhookHandler: emergencyWebhookHandler,
  );
}
