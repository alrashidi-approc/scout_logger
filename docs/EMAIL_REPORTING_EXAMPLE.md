# Email reporting example

Emails are **plain-text reports** for humans (engineering, product, support). JSON incidents still go to your HTTP handlers.

## Gmail (App Password)

1. Enable 2FA on the Google account.
2. Create an [App Password](https://myaccount.google.com/apppasswords) for “Mail”.
3. Use that 16-character password below (not your normal Gmail password).

```dart
import 'package:scout_logger/scout_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ScoutLogger logger = await ScoutAppLogger.init(
    ScoutLoggerConfig.blackbox(
      flavor: 'production',
      autoResolveAppInfo: true,
      onBatchIncidents: (jsonList) async {
        await http.post(
          Uri.parse('https://api.company.com/v1/incidents/batch'),
          body: jsonEncode(jsonList),
          headers: {'Content-Type': 'application/json'},
        );
        return true;
      },
      onUrgentIncident: (json) async {
        await http.post(
          Uri.parse('https://api.company.com/v1/incidents/urgent'),
          body: json,
          headers: {'Content-Type': 'application/json'},
        );
      },
      emailReporting: EmailReportingConfig.gmail(
        username: 'mobile-alerts@company.com',
        appPassword: 'abcd efgh ijkl mnop',
        fromAddress: 'mobile-alerts@company.com',
        senderName: 'Shop App Alerts',
        toAddresses: <String>[
          'engineering@company.com',
          'product@company.com',
        ],
        levels: <LogLevel>{
          LogLevel.error,
          LogLevel.fatal,
          LogLevel.critical,
        },
        subjectPrefix: '[Shop KW]',
      ),
    ),
  );

  logger.bindUser(
    userId: 'usr_100',
    sessionId: 'sess_abc',
    metadata: <String, dynamic>{
      'tenant': 'kw',
      'role': 'customer',
      'branchId': '12',
    },
  );

  runApp(MyApp(logger: logger));
}
```

## Custom SMTP (Office 365 example)

```dart
emailReporting: EmailReportingConfig(
  enabled: true,
  smtpHost: 'smtp.office365.com',
  smtpPort: 587,
  username: 'alerts@company.com',
  password: 'your-smtp-password',
  fromAddress: 'alerts@company.com',
  toAddresses: <String>['oncall@company.com'],
  levels: <LogLevel>{LogLevel.fatal, LogLevel.critical},
  subjectPrefix: '[Mobile Fatal]',
),
```

## What the team receives

```
MOBILE INCIDENT REPORT
========================

Summary
--------
Incident ID : 1739350123456789
Time (UTC)  : 2026-06-02T11:22:11.123Z
Time (local): 2026-06-02T14:22:11.123+03:00
Severity    : ERROR
Category    : NETWORK
Message     : API request failed
...
User meta   : {tenant: kw, role: customer, branchId: 12}
...
Waterfall   : {ttfb: 1.2, total: 5.0, ...}  (seconds)
```

## Tips

- Store SMTP credentials in **remote config** or **secure storage**, not in source control.
- Email runs in the background; failures never crash the app.
- Tune levels: e.g. only `fatal` + `critical` in production to reduce noise.
- Use `IncidentSharingPolicy` so email-related JSON payloads stay smaller (see `docs/BLACKBOX.md`).
