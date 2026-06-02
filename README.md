# Scout App Logger (`scout_logger`)

A Flutter **blackbox** for production apps: one JSON incident per issue (user, device, screen flow, API, crash stack), encrypted offline queue, and optional team email. **Dart-only** — no custom native plugin.

---

## Install

```yaml
dependencies:
  scout_logger:
    git:
      url: https://github.com/alrashidi-approc/scout_logger.git
  dio: ^5.9.0
```

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
| 4 | **Dio** | API logs, trace ID, PII scrub, timing |
| 5 | **Crashes** | Automatic fatal incidents → urgent upload |
| 6 | **Manual logs** | Business events with `logger.log` |
| 7 | **Dispatch** | Batch vs one-by-one upload |
| 8 | **Routing** | Different backends per log category |
| 9 | **Sharing policy** | Smaller JSON when full payload is not needed |
| 10 | **Email** | Plain-text reports to your team |
| 11 | **Remote level** | `updateLogLevelsRemote` from server |

Details: [`docs/BLACKBOX.md`](docs/BLACKBOX.md) · Sample JSON: [`docs/SAMPLE_INCIDENT.json`](docs/SAMPLE_INCIDENT.json)

---

## What you send to the backend

- **Batch:** `onBatchIncidents` → `List<String>` (each item is one incident JSON).
- **Urgent:** `onUrgentIncident` → one JSON string (crash / fatal / critical).
- Times: `time.utc` + `time.local` · API durations: `waterfallSec`.

---

## Try the demo

```bash
cd example
flutter pub get
flutter run
```

---

## Docs

| File | Content |
|------|---------|
| [docs/BLACKBOX.md](docs/BLACKBOX.md) | Full parameter reference |
| [docs/SAMPLE_INCIDENT.json](docs/SAMPLE_INCIDENT.json) | Example server payload |
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
| `dio.attachScoutLogger(logger)` | API calls appear in incidents |
| `navigatorObservers: [logger.navigatorObserver]` | User flow on errors |
| `bindUser` after login | Incidents tied to user + metadata |
| `onBatchIncidents` / `onUrgentIncident` implemented | Data reaches your servers |
| Optional `emailReporting` | Team gets readable emails |

---

## License

See [LICENSE](LICENSE).
