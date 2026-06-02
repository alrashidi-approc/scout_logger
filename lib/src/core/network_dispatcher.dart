import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/dispatch_policy.dart';
import '../config/logger_config.dart';
import '../models/log_models.dart';

class NetworkDispatcher {
  NetworkDispatcher(this._config);

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

  Future<bool> uploadBatch(List<LogEnvelope> logs) async {
    if (_config.serverRouting == null) {
      return _config.bulkUploadHandler(logs);
    }
    final Map<LogCategory, List<LogEnvelope>> groups = <LogCategory, List<LogEnvelope>>{};
    for (final LogEnvelope log in logs) {
      (groups[log.category] ??= <LogEnvelope>[]).add(log);
    }
    for (final MapEntry<LogCategory, List<LogEnvelope>> entry in groups.entries) {
      final bool ok = await _config.serverRouting!.bulkFor(entry.key)(entry.value);
      if (!ok) {
        return false;
      }
    }
    return true;
  }

  Future<bool> uploadSingle(LogEnvelope log) async {
    if (_config.serverRouting == null) {
      return _config.bulkUploadHandler(<LogEnvelope>[log]);
    }
    return _config.serverRouting!.bulkFor(log.category)(<LogEnvelope>[log]);
  }

  Future<void> notifyEmergency(LogEnvelope log) async {
    final EmergencyWebhookHandler handler = _config.serverRouting?.urgentFor(log.category) ??
        _config.emergencyWebhookHandler;
    await handler(log);
  }
}
