import '../models/log_models.dart';

/// Human-readable email reports for engineering / product teams (not raw JSON).
class EmailReportingConfig {
  const EmailReportingConfig({
    required this.enabled,
    required this.smtpHost,
    required this.smtpPort,
    required this.username,
    required this.password,
    required this.fromAddress,
    required this.toAddresses,
    this.levels = const <LogLevel>{
      LogLevel.error,
      LogLevel.fatal,
      LogLevel.critical,
    },
    this.useSsl = true,
    this.allowInsecure = false,
    this.subjectPrefix = '[Mobile Incident]',
    this.senderName,
    this.dedupeByGroupingKey = true,
    this.emailCooldown = const Duration(hours: 1),
    this.emailOnFirstOccurrence = true,
    this.emailOnRollup = true,
    this.maxBreadcrumbsInEmail = 5,
    this.maxStackTraceLines = 12,
  });

  final bool enabled;
  final String smtpHost;
  final int smtpPort;
  final String username;
  final String password;
  final String fromAddress;
  final List<String> toAddresses;
  final Set<LogLevel> levels;
  final bool useSsl;
  final bool allowInsecure;
  final String subjectPrefix;
  final String? senderName;
  final bool dedupeByGroupingKey;
  final Duration emailCooldown;
  final bool emailOnFirstOccurrence;
  final bool emailOnRollup;
  final int maxBreadcrumbsInEmail;
  final int maxStackTraceLines;

  bool shouldEmail(LogLevel level) => enabled && levels.contains(level);

  /// Gmail / Google Workspace (use an [App Password](https://support.google.com/accounts/answer/185833)).
  factory EmailReportingConfig.gmail({
    required String username,
    required String appPassword,
    required String fromAddress,
    required List<String> toAddresses,
    Set<LogLevel> levels = const <LogLevel>{
      LogLevel.error,
      LogLevel.fatal,
      LogLevel.critical,
    },
    String subjectPrefix = '[Mobile Incident]',
    String? senderName,
  }) {
    return EmailReportingConfig(
      enabled: true,
      smtpHost: 'smtp.gmail.com',
      smtpPort: 587,
      username: username,
      password: appPassword,
      fromAddress: fromAddress,
      toAddresses: toAddresses,
      levels: levels,
      useSsl: true,
      subjectPrefix: subjectPrefix,
      senderName: senderName,
    );
  }
}
