import 'dart:async';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/email_reporting_config.dart';
import '../models/log_models.dart';
import 'incident_email_formatter.dart';

class EmailIncidentReporter {
  EmailIncidentReporter(this._config);

  final EmailReportingConfig _config;

  void maybeSend(LogEnvelope envelope) {
    if (!_config.shouldEmail(envelope.level)) {
      return;
    }
    final Map<String, dynamic>? report = envelope.incidentReport;
    if (report == null) {
      return;
    }
    unawaited(_send(report));
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
      final String body = formatIncidentEmailBody(incident);
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
