/// Published package version embedded in incident JSON (`app.sdkVersion`).
const String kScoutLoggerSdkVersion = '1.0.0';

/// Default queue encryption key — must be overridden for production/staging flavors.
const String kScoutLoggerDefaultEncryptionKey = 'scout_logger_default_key';

const Set<String> kProductionFlavors = <String>{'production', 'staging', 'prod', 'stg'};
