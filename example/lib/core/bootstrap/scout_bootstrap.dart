import 'package:scout_logger/scout_logger.dart';

import '../device/demo_vitals_probe.dart';
import '../logging/demo_log_hub.dart';

/// Initializes Scout App Logger once (same pattern as production apps).
class ScoutBootstrap {
  ScoutBootstrap._();

  static ScoutLogger? _logger;

  static ScoutLogger get logger {
    final ScoutLogger? value = _logger;
    if (value == null) {
      throw StateError('Call ScoutBootstrap.init() in main() first.');
    }
    return value;
  }

  static Future<ScoutLogger> init(DemoLogHub hub) async {
    if (_logger != null) {
      return _logger!;
    }

    _logger = await ScoutAppLogger.init(
      ScoutLoggerConfig.blackbox(
        flavor: 'demo',
        autoResolveAppInfo: true,
        appContext: const BlackboxAppContext(
          appVersion: '0.0.0',
          buildNumber: '0',
          packageName: 'com.scoutlogger.demo',
          globalMetadata: <String, dynamic>{'demo': true},
        ),
        dispatchPolicy: const LogDispatchPolicy(
          mode: LogDispatchMode.chronoBatch,
          batchSize: 5,
          batchWindow: Duration(seconds: 15),
        ),
        encryptionKey: 'demo_encryption_key_change_in_production',
        minimumLevel: LogLevel.debug,
        networkLoggingPolicy: const NetworkLoggingPolicy(
          scope: NetworkLogScope.errorsOnly,
          nonErrorStatusCodes: <int>{401, 403, 404},
        ),
        onBatchIncidents: hub.handleBatchJson,
        onUrgentIncident: hub.handleUrgentJson,
        runtimeVitalsProbe: collectDemoRuntimeVitals,
      ),
    );

    _logger!.bindUser(
      userId: 'demo-user-1',
      sessionId: 'demo-session',
      metadata: <String, dynamic>{'tenant': 'demo', 'role': 'tester'},
    );

    return _logger!;
  }
}
