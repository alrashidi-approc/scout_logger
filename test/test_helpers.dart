import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:scout_logger/src/config/blackbox_app_context.dart';
import 'package:scout_logger/src/config/dispatch_policy.dart';
import 'package:scout_logger/src/config/logger_config.dart';
import 'package:scout_logger/src/config/connectivity_checker.dart';
import 'package:scout_logger/src/models/log_models.dart';

Future<List<ConnectivityResult>> kTestOnlineConnectivity() async =>
    <ConnectivityResult>[ConnectivityResult.wifi];

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
  LogDispatchPolicy dispatchPolicy = const LogDispatchPolicy(),
  String? queueStoragePath,
  String? emergencyStoragePath,
  ConnectivityChecker? connectivityChecker = kTestOnlineConnectivity,
  bool buildFullIncidentOnWarnOrHigher = true,
}) {
  return ScoutLoggerConfig(
    flavor: 'test',
    appContext: kTestAppContext,
    bulkUploadHandler: bulkUploadHandler,
    emergencyWebhookHandler: emergencyWebhookHandler,
    dispatchPolicy: dispatchPolicy,
    queueStoragePath: queueStoragePath,
    emergencyStoragePath: emergencyStoragePath,
    connectivityChecker: connectivityChecker,
    buildFullIncidentOnWarnOrHigher: buildFullIncidentOnWarnOrHigher,
  );
}
