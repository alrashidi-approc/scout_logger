import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/logger_config.dart';
import '../models/log_models.dart';

class NetworkDispatcher {
  const NetworkDispatcher(this._config);

  final ScoutLoggerConfig _config;

  Future<bool> canSyncNow() async {
    final List<ConnectivityResult> connectivity =
        await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return false;
    }
    if (_config.wifiOnlySync && !connectivity.contains(ConnectivityResult.wifi)) {
      return false;
    }
    return true;
  }

  Future<bool> uploadBatch(List<LogEnvelope> logs) =>
      _config.bulkUploadHandler(logs);

  Future<void> notifyEmergency(LogEnvelope log) =>
      _config.emergencyWebhookHandler(log);
}
