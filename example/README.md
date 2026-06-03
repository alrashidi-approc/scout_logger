# Scout App Logger — example demo

Interactive showcase using the same **clean architecture** layout as a production app.

## Run

```bash
flutter pub get
flutter run
```

Pick a device (iOS simulator, Android emulator, macOS, or Chrome).

## Project structure

```text
lib/
├── main.dart                          # ensureInitialized + AppContainer.init
├── app.dart                           # MaterialApp, routes, AppScope
├── core/
│   ├── bootstrap/scout_bootstrap.dart # ScoutAppLogger.init (once)
│   ├── di/
│   │   ├── app_container.dart         # wires logger, Dio, repository
│   │   └── app_scope.dart             # InheritedWidget for UI
│   ├── network/api_client.dart        # Dio + attachScoutLogger
│   └── logging/
│       ├── demo_log_hub.dart          # simulates your upload handlers
│       └── demo_log_entry.dart
└── features/
    └── demo/
        ├── data/demo_repository.dart  # use-cases (network, batch, levels)
        └── presentation/
            ├── pages/               # home, details, checkout
            └── widgets/             # console, actions, stats
```

## What to try

| Action | What it proves |
|--------|----------------|
| **UI trail** | `SmartUIObserver` breadcrumbs across routes |
| **Network OK / err / 401** | `errorsOnly` + ignored status codes |
| **PII scrub** | Redaction in network metadata |
| **Fill batch** | Encrypted queue + batch upload |
| **Error + vitals** | Device vitals + breadcrumbs on errors |
| **Fatal urgent** | Emergency webhook (skips batch) |
| **Fail urgent / batch** | Offline retry behavior |
| **Level: warn / debug** | `updateLogLevelsRemote` |

Handler output appears in the on-screen console (`DemoLogHub` stands in for your real `onBatchIncidents` / `onUrgentIncident`).

## Network logging config

Battery/charging in the demo uses **real device values** via `battery_plus` in `core/device/demo_vitals_probe.dart` (not random placeholders).

Network logging is set in `core/bootstrap/scout_bootstrap.dart`:

```dart
networkLoggingPolicy: const NetworkLoggingPolicy(
  scope: NetworkLogScope.errorsOnly,
  nonErrorStatusCodes: <int>{401, 403, 404},
),
```

| Demo button | Expected console |
|-------------|------------------|
| **Network OK** | No network log |
| **Network err** (503) | Failure log → batch |
| **401 ignored** | No log |
| **PII scrub** | Only if logged as failure |

Use `NetworkLogScope.all` to log every request/response again.
