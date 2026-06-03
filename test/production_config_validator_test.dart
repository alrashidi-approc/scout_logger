import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/logger_config.dart';
import 'package:scout_logger/src/config/production_config_validator.dart';
import 'package:scout_logger/src/config/sdk_constants.dart';

import 'test_helpers.dart';

void main() {
  test('allows default key for demo flavor', () {
    expect(
      () => assertProductionReadyConfig(
        testLoggerConfig(
          bulkUploadHandler: (_) async => true,
          emergencyWebhookHandler: (_) async {},
        ),
      ),
      returnsNormally,
    );
  });

  test('rejects default key for production flavor', () {
    expect(
      () => assertProductionReadyConfig(
        ScoutLoggerConfig(
          flavor: 'production',
          appContext: kTestAppContext,
          bulkUploadHandler: (_) async => true,
          emergencyWebhookHandler: (_) async {},
          encryptionKey: kScoutLoggerDefaultEncryptionKey,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('rejects short encryption key', () {
    expect(
      () => assertProductionReadyConfig(
        ScoutLoggerConfig(
          flavor: 'production',
          appContext: kTestAppContext,
          bulkUploadHandler: (_) async => true,
          emergencyWebhookHandler: (_) async {},
          encryptionKey: 'short',
        ),
      ),
      throwsArgumentError,
    );
  });
}
