# Scout App Logger (`scout_logger`)

**Current release: [v1.2.0](https://github.com/alrashidi-approc/scout_logger/releases/tag/v1.2.0)**

A Flutter **blackbox** for production apps: one JSON incident per issue (user, device, screen flow, API, crash stack), encrypted offline queue, batch + urgent upload, and optional team email. **Dart-only** — no custom native plugin.

---

## Install

Pin the tag in your `pubspec.yaml`:

```yaml
dependencies:
  scout_logger:
    git:
      url: https://github.com/alrashidi-approc/scout_logger.git
      ref: v1.2.0
  dio: ^5.9.0
```

For the latest `main` (unreleased), omit `ref`.

```bash
flutter pub get
```

Requires Dart **≥ 3.10** · Flutter **≥ 1.17**

---

## Parts of the SDK

| # | Feature | What it does |
|---|---------|----------------|
| 1 | **Init** | Crash hooks, encrypted queue, upload callbacks |
| 2 | **User** | `bindUser` + optional metadata (tenant, role, …) |
| 3 | **Navigation** | Screen flow via `navigatorObserver` |
| 4 | **Dio** | API logs, trace ID, PII scrub, timing, optional errors-only + status filters |
| 5 | **Crashes** | Automatic fatal incidents → urgent upload |
| 6 | **Manual logs** | `logger.error('…')` or full `logger.log(...)` |
| 7 | **Dispatch** | Batch vs one-by-one upload |
| 8 | **Routing** | Different backends per log category |
| 9 | **Sharing policy** | Smaller JSON when full payload is not needed |
| 10 | **Email** | Short alert emails (not log dumps); dedupe by `groupingKey` |
| 11 | **Remote level** | `updateLogLevelsRemote` from server |
| 12 | **App identity** | `app.name` + `deployment.appName` — partition all data per app on backend |
| 13 | **Triage** | `groupingKey`, tags, contexts, `deployment.release` (schema **1.2**) |
| 14 | **Repeat issues** | Same error counted; rollup upload after cooldown (no spam) |
| 15 | **Custom payload** | `customMetadata` / `scoutIncidentCustom` — app fields without duplicating network data |
| 16 | **Simple logs** | `ScoutAppLogger.error('…')` without full `log(...)` boilerplate |

Details: [`docs/BLACKBOX.md`](docs/BLACKBOX.md) · **Sample incident (schema 1.2):** [`docs/SAMPLE_INCIDENT.json`](docs/SAMPLE_INCIDENT.json) · **Backend guide:** [`docs/BACKEND_INGESTION.md`](docs/BACKEND_INGESTION.md) · **Changelog:** [`CHANGELOG.md`](CHANGELOG.md)

---

## What’s new in v1.2.0

- **`app.name`** / **`deployment.appName`** — route all incidents to one backend bucket per app.
- **Repeat issues** — same `groupingKey` counted; rollup after cooldown; smarter deduped email + urgent webhook.
- **Leaner JSON** — network data only in `network.triggering`; app extras via `customMetadata` or Dio `scoutIncidentCustom`.

Upgrade from 1.1.0: add `appName:` on init, set `occurrencePolicy` if you want dedupe (defaults are on), use `customMetadata` instead of putting app fields in Dio `metadata`.

---

## Production checklist

Before shipping to **production** / **staging**:

| Requirement | Why |
|---------------|-----|
| Unique `encryptionKey` (≥ 16 chars) | Default key is **rejected** for `production` / `staging` flavors at `init` |
| `runtimeVitalsProbe` for battery/charging | Dart-only SDK; hosts supply real vitals |
| `appName` on init | Same label on every incident → one backend bucket per app |
| `bindUser` after login | Incidents tied to `userId` / `sessionId` |
| `dio.attachScoutLogger(logger)` | Network failures + `X-Trace-ID` for server correlation |
| `networkLoggingPolicy` | Usually `errorsOnly` + ignore `401`/`403`/`404` |
| Handlers return `true` only after server ACK | Batch retry + offline queue depend on this |
| Urgent handler must not throw on success | Failures go to encrypted urgent queue |

```dart
await ScoutAppLogger.init(
  ScoutLoggerConfig.blackbox(
    flavor: 'production',
    appName: 'Your App', // → app.name & deployment.appName on every incident
    encryptionKey: const String.fromEnvironment('SCOUT_LOG_KEY'),
    runtimeVitalsProbe: yourVitalsProbe,
    networkLoggingPolicy: const NetworkLoggingPolicy(
      scope: NetworkLogScope.errorsOnly,
      nonErrorStatusCodes: <int>{401, 403, 404},
    ),
    onBatchIncidents: yourBatchHandler,
    onUrgentIncident: yourUrgentHandler,
    release: 'com.yourapp@2.4.1+204',
    environment: 'production',
    productInsightsPolicy: const ProductInsightsPolicy(
      sampleRate: 1.0,
      trackAppLifecycle: true,
      occurrencePolicy: IncidentOccurrencePolicy(
        rollupCooldown: Duration(minutes: 15),
        suppressDuplicateUrgent: true,
      ),
    ),
    // emailReporting: EmailReportingConfig.gmail(
    //   dedupeByGroupingKey: true,
    //   emailCooldown: Duration(hours: 1),
    //   ...
    // ),
  ),
);
ScoutAppLogger.setTag('feature', 'checkout');
ScoutAppLogger.breadcrumb('TAP_PAY');

// Simple logs (internal + logic by default)
await ScoutAppLogger.error('Payment failed', stackTrace: stack.toString());
await ScoutAppLogger.warn('Checkout slow');
await ScoutAppLogger.info('Cart opened');
```

Incidents use schema **1.2** with **`app.name`** (backend partition key), **`triage.groupingKey`** (same-issue dedupe), **`triage.occurrence`** (repeat counts), **`deployment.release`**, **`session`**, and full user flow. See [`docs/BACKEND_INGESTION.md`](docs/BACKEND_INGESTION.md) and [`docs/SAMPLE_INCIDENT.json`](docs/SAMPLE_INCIDENT.json).

---

## App name (one backend bucket per app)

Set once at init so batch + urgent handlers can route everything to the same store:

| Field | Use on backend |
|-------|----------------|
| `app.name` | Primary partition key (human-readable, e.g. `Diyar Wallet`) |
| `deployment.appName` | Same value — for pipelines that index `deployment` |
| `app.packageName` | Bundle id (`com.company.shop`) |

```dart
ScoutLoggerConfig.blackbox(
  appName: 'Diyar Wallet',
  autoResolveAppInfo: true, // fills version/build/package; keeps your appName
  // ...
)
```

With `autoResolveAppInfo: true` and no `appName`, the SDK uses the platform display name from `PackageInfo`, then falls back to `packageName`.

---

## Custom fields on incidents

For **NETWORK** errors, Dio data lives only in `network.triggering`. App-specific fields go in **`custom`** via:

| API | Use when |
|-----|----------|
| `customMetadata:` on `log()` / `ScoutAppLogger.error(...)` | Manual logs |
| `ScoutAppLogger.setGlobalMetadata({...})` | Same on every incident |
| `options.scoutIncidentCustom = {...}` on Dio | Per API call (inbox id, feature, …) |

```dart
// Per failed GET — merged into incident custom, not duplicated in network
options.scoutIncidentCustom = {
  'feature': 'inbox',
  'civilId': userId,
};

await ScoutAppLogger.error(
  'Checkout validation failed',
  customMetadata: {'step': 'pay', 'orderId': orderId},
);
```

---

## Repeat issues (no spam, still get counts)

The same `groupingKey` within a session:

1. **First** — full upload + optional email (`triage.occurrence.reportReason: "first"`).
2. **Repeats** — counted locally, **not** uploaded/emailed.
3. **After cooldown** (default 15 min) — one **rollup** with `occurrence.count` and `sinceLastReport`.

Urgent webhooks for fatals fire **once per grouping key** unless you change `IncidentOccurrencePolicy.suppressDuplicateUrgent`.

---

## What you send to the backend

- **Batch:** `onBatchIncidents` → `List<String>` (each item is one incident JSON, schema **1.2**).
- **Urgent:** `onUrgentIncident` → one JSON string (first fatal per issue; rollups go batch).
- **Partition:** filter/group by `app.name` (or `deployment.appName`).
- **Same issue:** `triage.groupingKey` + `triage.occurrence.count`.
- **Server correlation:** `network.triggering.traceId` = your `X-Trace-ID`.
- Times: `time.utc` + `time.local` · API durations: `waterfallSec`.

---

## Try the demo

```bash
cd example
flutter pub get
flutter run
```

The `example/` app uses **clean architecture** (`core/` bootstrap + network, `features/demo/` repository + UI). See [example/README.md](example/README.md).

---

## Docs

| File | Content |
|------|---------|
| [docs/BLACKBOX.md](docs/BLACKBOX.md) | Full parameter reference |
| [docs/BACKEND_INGESTION.md](docs/BACKEND_INGESTION.md) | Backend / on-call field guide |
| [docs/SAMPLE_INCIDENT.json](docs/SAMPLE_INCIDENT.json) | Example incident JSON (schema 1.2) |
| [docs/EMAIL_REPORTING_EXAMPLE.md](docs/EMAIL_REPORTING_EXAMPLE.md) | Gmail / SMTP setup |

---

## Develop

```bash
flutter pub get
flutter test
```

---

## Implement in a real app

Typical production layout: bootstrap once, inject `ApiClient` everywhere, bind user after login, observer on `MaterialApp`.

### Folder structure

```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── bootstrap/scout_bootstrap.dart   # init SDK once
│   ├── network/api_client.dart          # Dio + attachScoutLogger
│   └── logging/incident_api.dart        # your HTTP ingest
└── features/
    ├── auth/data/auth_repository.dart   # bindUser on login
    └── checkout/presentation/checkout_screen.dart
```

---

### `lib/core/logging/incident_api.dart`

Your backend — swap URLs and auth.

```dart
import 'package:dio/dio.dart';
import 'package:scout_logger/scout_logger.dart';

class IncidentApi {
  IncidentApi(this._dio);

  final Dio _dio;

  Future<bool> postBatch(List<String> incidents) async {
    final Response<dynamic> res = await _dio.post(
      '/v1/incidents/batch',
      data: incidents,
    );
    return res.statusCode == 200;
  }

  Future<void> postUrgent(String incidentJson) async {
    await _dio.post('/v1/incidents/urgent', data: incidentJson);
  }
}
```

---

### `lib/core/bootstrap/scout_bootstrap.dart`

Run from `main()` before `runApp`.

```dart
import 'package:scout_logger/scout_logger.dart';

import '../logging/incident_api.dart';

class ScoutBootstrap {
  static ScoutLogger? _logger;

  static ScoutLogger get logger {
    final ScoutLogger? value = _logger;
    if (value == null) {
      throw StateError('Call ScoutBootstrap.init() in main() first.');
    }
    return value;
  }

  static Future<ScoutLogger> init(IncidentApi incidentApi) async {
    if (_logger != null) {
      return _logger!;
    }

    _logger = await ScoutAppLogger.init(
      ScoutLoggerConfig.blackbox(
        flavor: const String.fromEnvironment('FLAVOR', defaultValue: 'production'),
        appName: 'Your App',
        autoResolveAppInfo: true,
        encryptionKey: const String.fromEnvironment('LOG_KEY'),
        minimumLevel: LogLevel.info,
        dispatchPolicy: const LogDispatchPolicy(
          batchSize: 50,
          batchWindow: Duration(seconds: 120),
        ),
        incidentSharingPolicy: const IncidentSharingPolicy(
          defaultLevel: IncidentDetailLevel.focused,
          fullPayloadLevels: {LogLevel.fatal, LogLevel.critical},
        ),
        onBatchIncidents: incidentApi.postBatch,
        onUrgentIncident: incidentApi.postUrgent,
        release: 'com.yourapp@1.0.0+1',
        environment: 'production',
        productInsightsPolicy: const ProductInsightsPolicy(
          trackAppLifecycle: true,
          occurrencePolicy: IncidentOccurrencePolicy(
            rollupCooldown: Duration(minutes: 15),
          ),
        ),
        networkLoggingPolicy: const NetworkLoggingPolicy(
          scope: NetworkLogScope.errorsOnly,
          nonErrorStatusCodes: <int>{401, 403, 404},
        ),
        runtimeVitalsProbe: () async => {
          'thermalState': 'nominal',
        },
        // Optional team email — see docs/EMAIL_REPORTING_EXAMPLE.md
        // emailReporting: EmailReportingConfig.gmail(...),
      ),
    );

    return _logger!;
  }
}
```

---

### `lib/core/network/api_client.dart`

One shared `Dio` for the app and for incident upload.

```dart
import 'package:dio/dio.dart';
import 'package:scout_logger/scout_logger.dart';

import '../bootstrap/scout_bootstrap.dart';
import '../logging/incident_api.dart';

class ApiClient {
  ApiClient._(this.dio, this.incidents);

  final Dio dio;
  final IncidentApi incidents;

  static Future<ApiClient> create() async {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.yourcompany.com',
        connectTimeout: const Duration(seconds: 20),
      ),
    );

    final IncidentApi incidentApi = IncidentApi(dio);
    final ScoutLogger logger = await ScoutBootstrap.init(incidentApi);

    dio.attachScoutLogger(logger);

    return ApiClient._(dio, incidentApi);
  }
}
```

#### Network logging scope (errors vs everything)

Set once on `ScoutLoggerConfig.networkLoggingPolicy`:

```dart
networkLoggingPolicy: const NetworkLoggingPolicy(
  // Log only real failures — not every 200 or 401
  scope: NetworkLogScope.errorsOnly,
  // HTTP codes your app treats as expected (no error log)
  nonErrorStatusCodes: <int>{401, 403, 404},
),
```

| `NetworkLogScope` | Behavior |
|-------------------|----------|
| `all` | Request start + success + failure logs (feeds `network.recent` on errors). **Only ERROR+ incidents are uploaded** — DEBUG/INFO are not schema 1.2 JSON. |
| `errorsOnly` | Failures only (still honors `nonErrorStatusCodes`). **Recommended for production.** |

`401` is in the default ignore list so unauthorized responses are not logged as `API request failed`. Use **`errorsOnly`** to avoid extra Dio noise; use **`all`** only if you need richer `network.recent` context on failures (upload behavior is the same for errors).

---

### `lib/main.dart`

```dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/api_client.dart';

late final ApiClient api;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  api = await ApiClient.create();
  runApp(MyApp(api: api));
}
```

---

### `lib/app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:scout_logger/scout_logger.dart';

import 'core/bootstrap/scout_bootstrap.dart';
import 'core/network/api_client.dart';
import 'features/checkout/presentation/checkout_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final ScoutLogger logger = ScoutBootstrap.logger;

    return MaterialApp(
      navigatorObservers: [logger.navigatorObserver],
      initialRoute: '/home',
      routes: {
        '/home': (_) => const HomeScreen(),
        '/checkout': (_) => CheckoutScreen(api: api),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.pushNamed(context, '/checkout'),
          child: const Text('Checkout'),
        ),
      ),
    );
  }
}
```

---

### `lib/features/auth/data/auth_repository.dart`

Call after login / logout (generic app metadata supported).

```dart
import 'package:scout_logger/scout_logger.dart';

class AuthRepository {
  Future<void> signIn({
    required String userId,
    required String sessionId,
    required String tenant,
    required String role,
  }) async {
    ScoutAppLogger.bindUser(
      userId: userId,
      sessionId: sessionId,
      metadata: {
        'tenant': tenant,
        'role': role,
      },
    );
    ScoutAppLogger.setGlobalMetadata({'locale': 'ar'});
  }

  Future<void> signOut() async {
    ScoutAppLogger.bindUser(
      userId: 'anonymous',
      sessionId: 'signed-out',
    );
  }

  Future<void> syncRemoteLogLevel() async {
    // After fetching your remote config API:
    await ScoutAppLogger.instance.updateLogLevelsRemote(
      minimumLevel: LogLevel.warn,
      userId: 'current-user-id',
    );
  }
}
```

---

### `lib/features/checkout/presentation/checkout_screen.dart`

Navigation is already tracked. Add breadcrumbs + manual logs where it matters.

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:scout_logger/scout_logger.dart';

import '../../../core/bootstrap/scout_bootstrap.dart';
import '../../../core/network/api_client.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final ScoutLogger logger = ScoutBootstrap.logger;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: FilledButton(
        onPressed: () => _pay(logger),
        child: const Text('Pay'),
      ),
    );
  }

  Future<void> _pay(ScoutLogger logger) async {
    logger.navigatorObserver.addManualBreadcrumb(
      'TAP_PAY',
      metadata: {'screen': 'checkout'},
    );

    try {
      await api.dio.post('/payments/charge', data: {'orderId': 'ord_99'});
    } on DioException catch (e, stack) {
      await logger.log(
        domain: Domain.internal,
        category: LogCategory.logic,
        level: LogLevel.error,
        message: 'Payment failed',
        metadata: {'orderId': 'ord_99'},
        stackTrace: stack.toString(),
      );
    }
  }
}
```

---

### Crashes (no extra screen code)

After `ScoutBootstrap.init`, uncaught errors are logged as **FATAL** and sent to `postUrgent`. If the device is offline, the SDK stores the incident and retries on the next sync.

---

### Checklist

| Step | Done when |
|------|-----------|
| `ScoutBootstrap.init` in `main` before `runApp` | SDK + crash hooks live |
| `dio.attachScoutLogger(logger)` | API calls appear in incidents (per `networkLoggingPolicy`) |
| `networkLoggingPolicy` set | Errors-only and/or ignore 401, 403, 404 as non-errors |
| `navigatorObservers: [logger.navigatorObserver]` | User flow on errors |
| `bindUser` after login | Incidents tied to user + metadata |
| `appName` set | All incidents land in the right backend app bucket |
| `onBatchIncidents` / `onUrgentIncident` implemented | Data reaches your servers |
| Optional `emailReporting` | Short alerts; deduped by `groupingKey` |

---

## With `dio_resilient` (retries + cache + offline queue)

Use **one shared `Dio`**: Scout for incidents, `dio_resilient` for resilience. Pin both by git tag.

```yaml
dependencies:
  scout_logger:
    git:
      url: https://github.com/alrashidi-approc/scout_logger.git
      ref: v1.2.2
  dio_resilient:
    git:
      url: https://github.com/diyar/dio_resilient.git
      ref: v2.2.2
```

```dart
dio = Dio(BaseOptions(baseUrl: baseUrl));
scout = await ScoutAppLogger.init(ScoutLoggerConfig.blackbox(
  networkLoggingPolicy: const NetworkLoggingPolicy(
    scope: NetworkLogScope.errorsOnly,
    nonErrorStatusCodes: <int>{401, 403, 404},
  ),
  // ...
));
dio.attachScoutLogger(scout);

resilient = await DioResilient.attach(
  dio: dio,
  databaseDirectoryPath: dir.path,
  options: const DioResilientOptions(
    requestLogMode: RequestLogMode.errorsOnly,
  ),
);

// Use resilient.get/post for resilient routes — Scout still logs real HTTP failures
await resilient.get('/inbox', options: Options()..scoutIncidentCustom = {'feature': 'inbox'});
```

See [dio_resilient README — scout_logger section](https://github.com/diyar/dio_resilient#using-with-scout_logger-recommended-epa--production-stack) for attach order and what each layer logs.

---

## License

See [LICENSE](LICENSE).
