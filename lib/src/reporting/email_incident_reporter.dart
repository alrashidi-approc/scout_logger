import 'dart:async';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/email_reporting_config.dart';
import '../models/log_models.dart';
import 'incident_email_formatter.dart';

class EmailIncidentReporter {
  EmailIncidentReporter(this._config);

  final EmailReportingConfig _config;
  final Map<String, DateTime> _lastEmailAtByGroupingKey = <String, DateTime>{};

  void maybeSend(LogEnvelope envelope) {
    if (!_config.shouldEmail(envelope.level)) {
      return;
    }
    final Map<String, dynamic>? report = envelope.incidentReport;
    if (report == null) {
      return;
    }
    if (!_shouldSendEmail(report, envelope.timestamp)) {
      return;
    }
    unawaited(_send(report));
  }

  bool _shouldSendEmail(Map<String, dynamic> incident, DateTime at) {
    final Map<String, dynamic> triage =
        incident['triage'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic>? occurrence =
        triage['occurrence'] as Map<String, dynamic>?;
    final String? reason = occurrence?['reportReason'] as String?;

    if (reason == 'rollup' && !_config.emailOnRollup) {
      return false;
    }
    if ((reason == null || reason == 'first') && !_config.emailOnFirstOccurrence) {
      return false;
    }

    if (!_config.dedupeByGroupingKey) {
      return true;
    }

    final String? groupingKey = triage['groupingKey'] as String?;
    if (groupingKey == null || groupingKey.isEmpty) {
      return true;
    }

    if (reason == 'first' || reason == null) {
      _lastEmailAtByGroupingKey[groupingKey] = at;
      return true;
    }

    if (reason != 'rollup') {
      return false;
    }

    final DateTime? last = _lastEmailAtByGroupingKey[groupingKey];
    if (last != null && at.difference(last) < _config.emailCooldown) {
      return false;
    }
    _lastEmailAtByGroupingKey[groupingKey] = at;
    return true;
  }

  Future<void> _send(Map<String, dynamic> incident) async {
    try {
      final SmtpServer server = SmtpServer(
        _config.smtpHost,
        port: _config.smtpPort,
        username: _config.username,
        password: _config.password,
        ssl: _config.useSsl && _config.smtpPort == 465,
        allowInsecure: _config.allowInsecure,
      );
      final String body = formatIncidentEmailBody(
        incident,
        maxBreadcrumbs: _config.maxBreadcrumbsInEmail,
        maxStackTraceLines: _config.maxStackTraceLines,
      );
      final String subject = formatIncidentEmailSubject(incident, _config.subjectPrefix);
      final Message message = Message()
        ..from = Address(_config.fromAddress, _config.senderName)
        ..recipients.addAll(_config.toAddresses)
        ..subject = subject
        ..text = body;
      await send(message, server);
    } catch (_) {
      // Email must never crash the host app.
    }
  }
}
