# Blackbox integration guide

Pass parameters once → SDK auto-collects device/app/connectivity → emits **one JSON incident** per issue → your servers (and optional email teams) receive everything.

Sample payload: [`SAMPLE_INCIDENT.json`](SAMPLE_INCIDENT.json)

---

## Minimal blackbox setup

```dart
final logger = await ScoutAppLogger.init(
  ScoutLoggerConfig.blackbox(
    flavor: 'production',
    autoResolveAppInfo: true, // version, build, package from package_info_plus
    onBatchIncidents: (jsonList) async {
      await analyticsApi.post('/v1/incidents/batch', body: jsonList);
      return true;
    },
    onUrgentIncident: (json) async {
      await crashApi.post('/v1/incidents/urgent', body: json);
    },
    dispatchPolicy: const LogDispatchPolicy(
      mode: LogDispatchMode.chronoBatch,
      batchSize: 50,
      batchWindow: Duration(seconds: 120),
      wifiOnlySync: false,
    ),
  ),
);

dio.attachScoutLogger(logger);
MaterialApp(navigatorObservers: [logger.navigatorObserver]);

ScoutAppLogger.bindUser(userId: user.id, sessionId: sessionId);
```

---

## Parameters reference

### Auto-collected (no manual input)

| Data | Package |
|------|---------|
| App version, build, package name | `package_info_plus` (when `autoResolveAppInfo: true`) |
| Device model, OS, manufacturer, SDK int | `device_info_plus` |
| Battery level & state | `runtimeVitalsProbe` or `scout_logger/system` channel |
| RAM used | `dart:io` `ProcessInfo` |
| Connectivity online + types | `connectivity_plus` |
| Navigation user flow | `SmartUIObserver` |
| API trace, waterfall, PII-scrubbed bodies | Dio interceptor |

Optional: `runtimeVitalsProbe` for extra thermal/RAM if needed.

### You provide

| Parameter | Required | Notes |
|-----------|----------|-------|
| `flavor` | yes | `dev` / `staging` / `production` |
| `onBatchIncidents` | yes* | List of incident JSON strings |
| `onUrgentIncident` | yes* | Single incident JSON for fatal/critical |
| `encryptionKey` | prod yes | Offline queue encryption |
| `dispatchPolicy` | no | Batch vs one-by-one (below) |
| `serverRouting` | no | Separate servers per category |
| `emailReporting` | no | Human-readable SMTP reports |
| `bindUser` | after login | `userId`, `sessionId` |
| `setGlobalMetadata` | no | Tenant, locale, flags → `custom` section |

\*Or use `bulkUploadHandler` / `emergencyWebhookHandler` with `LogEnvelope` if not using `.blackbox()`.

### `BlackboxAppContext` (when `autoResolveAppInfo: false`)

| Field | Required |
|-------|----------|
| `appVersion` | yes |
| `buildNumber` | yes |
| `packageName` | yes |
| `userId` / `sessionId` | recommended |
| `globalMetadata` | optional |

---

## Dispatch control (big apps)

### `LogDispatchPolicy`

| Field | Default | Purpose |
|-------|---------|---------|
| `mode` | `chronoBatch` | `chronoBatch` or `perLog` (one JSON per log) |
| `batchSize` | `50` | Max incidents per HTTP call |
| `batchWindow` | `120s` | Max wait before flush |
| `wifiOnlySync` | `false` | Upload only on Wi‑Fi |
| `maxRetryBackoffSeconds` | `300` | Backoff cap when upload fails |

**Batch mode** (typical): queue encrypted → upload N incidents per request.

**Per-log mode**: each log uploaded individually (still queued offline).

```dart
dispatchPolicy: const LogDispatchPolicy(
  mode: LogDispatchMode.perLog,
  wifiOnlySync: true,
),
onSingleIncident: (json) async => api.post('/incident', body: json),
```

### Separate backend servers (`LogServerRouting`)

```dart
serverRouting: LogServerRouting(
  defaultBulk: (logs) => mainIngest.post(logs),
  networkBulk: (logs) => networkService.post(logs),
  crashBulk: (logs) => crashService.post(logs),
  defaultUrgent: (log) => pager.post(log),
  networkUrgent: (log) => networkPager.post(log),
),
```

Batch uploads are **split by category** and sent to the matching handler.

---

## Email reporting (teams, not JSON)

Human-readable plain-text email for selected levels (default: ERROR, FATAL, CRITICAL).

```dart
emailReporting: EmailReportingConfig.gmail(
  username: 'mobile-alerts@company.com',
  appPassword: 'xxxx xxxx xxxx xxxx', // Gmail App Password
  fromAddress: 'mobile-alerts@company.com',
  senderName: 'Shop App Alerts',
  toAddresses: <String>[
    'engineering@company.com',
    'product@company.com',
  ],
  levels: <LogLevel>{LogLevel.error, LogLevel.fatal, LogLevel.critical},
  subjectPrefix: '[Shop KW]',
),
```

Custom SMTP:

```dart
EmailReportingConfig(
  enabled: true,
  smtpHost: 'smtp.office365.com',
  smtpPort: 587,
  username: '...',
  password: '...',
  fromAddress: '...',
  toAddresses: <String>['team@company.com'],
),
```

Email includes: summary, app/user/device, connectivity, screen flow, API details, stack — **not** raw JSON (JSON still goes to your HTTP handlers).

**Security:** never commit passwords; use CI secrets or remote config.

Full copy-paste example: **[EMAIL_REPORTING_EXAMPLE.md](EMAIL_REPORTING_EXAMPLE.md)**

---

## `bindUser` with extra metadata (generic / multi-tenant apps)

```dart
ScoutAppLogger.bindUser(
  userId: user.id,
  sessionId: sessionId,
  metadata: <String, dynamic>{
    'tenant': 'kw',
    'role': 'cashier',
    'branchId': '12',
    'locale': 'ar',
  },
);
```

Appears in every incident as `user.metadata` (merged on each call).

---

## Smarter JSON size (`IncidentSharingPolicy`)

Same top-level keys always; sections you do not need are `null` (easier parsers, smaller payloads).

```dart
incidentSharingPolicy: IncidentSharingPolicy(
  defaultLevel: IncidentDetailLevel.focused,
  byCategory: {
    LogCategory.logic: IncidentDetailLevel.minimal,
  },
  fullPayloadLevels: {LogLevel.fatal, LogLevel.critical},
),
```

| Level | When to use |
|-------|----------------|
| `minimal` | Only event + app + user |
| `focused` | Category-aware (network errors → network block, etc.) |
| `full` | Everything (default for fatal/critical) |

See `payload.sectionsIncluded` in each incident.

---

## Readable time & durations

- `time.utc` + `time.local` (ISO-8601) — not raw microsecond integers in the main fields.
- `timestamp` = `time.utc` (backward compatible).
- `waterfallSec` next to `waterfallUs` (seconds, 3 decimal places).
- Breadcrumb steps use `time.utc` / `time.local` per step.

---

## JSON sent to your servers

Each item in `onBatchIncidents` or `onUrgentIncident` is `log.toIncidentJson()`:

See full example: [`SAMPLE_INCIDENT.json`](SAMPLE_INCIDENT.json)

Top-level keys: `schemaVersion`, `incidentId`, `time`, `timestamp`, `event`, `app`, `user`, `device`, `connectivity`, `screen`, `network`, `custom`, `payload`.

Store as-is in your DB / forward to Datadog / Elasticsearch. Index: `incidentId`, `user.userId`, `event.level`, `network.triggering.traceId`, `app.flavor`, `timestamp`.

---

## Backend ingest example

```http
POST /v1/incidents/batch
Content-Type: application/json

[
  "{ \"schemaVersion\":\"1.0\", \"incidentId\":\"...\", ... }",
  "{ ... }"
]
```

Or parse JSON objects if you decode strings server-side.

Urgent:

```http
POST /v1/incidents/urgent
Content-Type: application/json

{ "schemaVersion": "1.0", ... }
```
