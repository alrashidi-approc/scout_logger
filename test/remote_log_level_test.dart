import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/dispatch_policy.dart';
import 'package:scout_logger/src/core/scout_logger_manager.dart';
import 'package:scout_logger/src/models/log_models.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(ScoutLogger.resetForTesting);

  test('updateLogLevelsRemote filters logs below active minimum', () async {
    final String base =
        '${Directory.systemTemp.path}/scout_remote_level_${DateTime.now().microsecondsSinceEpoch}';
    int uploaded = 0;
    final ScoutLogger logger = await ScoutLogger.init(
      testLoggerConfig(
        bulkUploadHandler: (List<LogEnvelope> logs) async {
          uploaded += logs.length;
          return true;
        },
        emergencyWebhookHandler: (_) async {},
        dispatchPolicy: const LogDispatchPolicy(mode: LogDispatchMode.perLog),
        queueStoragePath: '$base/queue.enc',
        emergencyStoragePath: '$base/emergency.enc',
        buildFullIncidentOnWarnOrHigher: false,
      ),
    );

    await logger.log(
      domain: Domain.internal,
      category: LogCategory.logic,
      level: LogLevel.debug,
      message: 'debug',
    );
    await logger.log(
      domain: Domain.internal,
      category: LogCategory.logic,
      level: LogLevel.info,
      message: 'info',
    );
    expect(uploaded, 1);

    await logger.updateLogLevelsRemote(minimumLevel: LogLevel.warn);
    await logger.log(
      domain: Domain.internal,
      category: LogCategory.logic,
      level: LogLevel.info,
      message: 'info-after-raise',
    );
    await logger.log(
      domain: Domain.internal,
      category: LogCategory.logic,
      level: LogLevel.warn,
      message: 'warn-after-raise',
    );
    expect(uploaded, 2);
  });
}
