import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/dispatch_policy.dart';
import 'package:scout_logger/src/core/network_dispatcher.dart';
import 'package:scout_logger/src/models/log_models.dart';

import 'test_helpers.dart';

void main() {
  test('blocks sync when offline', () async {
    final NetworkDispatcher dispatcher = NetworkDispatcher(
      testLoggerConfig(
        bulkUploadHandler: _noopBulk,
        emergencyWebhookHandler: _noopEmergency,
      ),
      connectivityChecker: () async => <ConnectivityResult>[ConnectivityResult.none],
    );
    expect(await dispatcher.canSyncNow(), isFalse);
  });

  test('wifiOnlySync requires wifi connectivity', () async {
    final NetworkDispatcher cellular = NetworkDispatcher(
      _wifiOnlyConfig,
      connectivityChecker: () async => <ConnectivityResult>[ConnectivityResult.mobile],
    );
    final NetworkDispatcher wifi = NetworkDispatcher(
      _wifiOnlyConfig,
      connectivityChecker: () async => <ConnectivityResult>[ConnectivityResult.wifi],
    );

    expect(await cellular.canSyncNow(), isFalse);
    expect(await wifi.canSyncNow(), isTrue);
  });

  test('allows cellular when wifiOnlySync is false', () async {
    final NetworkDispatcher dispatcher = NetworkDispatcher(
      testLoggerConfig(
        bulkUploadHandler: _noopBulk,
        emergencyWebhookHandler: _noopEmergency,
      ),
      connectivityChecker: () async => <ConnectivityResult>[ConnectivityResult.mobile],
    );
    expect(await dispatcher.canSyncNow(), isTrue);
  });
}

final _wifiOnlyConfig = testLoggerConfig(
  bulkUploadHandler: _noopBulk,
  emergencyWebhookHandler: _noopEmergency,
  dispatchPolicy: const LogDispatchPolicy(wifiOnlySync: true),
);

Future<bool> _noopBulk(List<LogEnvelope> logs) async => true;
Future<void> _noopEmergency(LogEnvelope log) async {}
