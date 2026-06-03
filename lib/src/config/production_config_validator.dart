import 'logger_config.dart';
import 'sdk_constants.dart';

/// Throws [ArgumentError] when config would be unsafe to ship to production.
void assertProductionReadyConfig(ScoutLoggerConfig config) {
  final String flavor = config.flavor.trim().toLowerCase();
  if (kProductionFlavors.contains(flavor) &&
      config.encryptionKey == kScoutLoggerDefaultEncryptionKey) {
    throw ArgumentError(
      'scout_logger: set a unique encryptionKey for flavor "${config.flavor}". '
      'Do not use kScoutLoggerDefaultEncryptionKey in production.',
    );
  }
  if (config.encryptionKey.length < 16) {
    throw ArgumentError(
      'scout_logger: encryptionKey must be at least 16 characters.',
    );
  }
}
