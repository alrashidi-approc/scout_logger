import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/dispatch_policy.dart';
import 'package:scout_logger/src/config/logger_config.dart';
import 'package:scout_logger/src/config/product_insights_policy.dart';
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
      ).copyWith(
        productInsightsPolicy: const ProductInsightsPolicy(
          trackAppLifecycle: false,
        ),
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
    expect(uploaded, 0);

    await logger.log(
      domain: Domain.internal,
      category: LogCategory.logic,
      level: LogLevel.error,
      message: 'error-before-raise',
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
      level: LogLevel.error,
      message: 'error-after-raise',
    );
    expect(uploaded, 2);
  });
}

extension on ScoutLoggerConfig {
  ScoutLoggerConfig copyWith({ProductInsightsPolicy? productInsightsPolicy}) {
    return ScoutLoggerConfig(
      flavor: flavor,
      bulkUploadHandler: bulkUploadHandler,
      emergencyWebhookHandler: emergencyWebhookHandler,
      appContext: appContext,
      encryptionKey: encryptionKey,
      dispatchPolicy: dispatchPolicy,
      queueStoragePath: queueStoragePath,
      emergencyStoragePath: emergencyStoragePath,
      connectivityChecker: connectivityChecker,
      buildFullIncidentOnWarnOrHigher: buildFullIncidentOnWarnOrHigher,
      productInsightsPolicy: productInsightsPolicy ?? this.productInsightsPolicy,
    );
  }
}
