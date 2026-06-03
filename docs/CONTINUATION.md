# Continue Development Anywhere

Use this file to resume work on the Scout App Logger SDK (`scout_logger` package on disk).

## Repository

- **Remote:** https://github.com/alrashidi-approc/scout_logger.git
- **Branch:** `main`
- **Clone:** `git clone https://github.com/alrashidi-approc/scout_logger.git`

## Cursor / Agent Context

- **Workspace rule:** `.cursor/rules/scout-app-logger-role.mdc` (always applied)
- **Feature pack docs:** `docs/feature-packs/` (grouped implementation history)
- **This handoff:** `docs/CONTINUATION.md`

## Product Goal

Production-grade Flutter client logging SDK — a mobile “flight data recorder” for UI breadcrumbs, network waterfalls, encrypted offline queue, batch upload, crash hooks, and urgent fatal dispatch — without blocking the UI thread.

Public API naming target: `ScoutAppLogger` (facade exists; internal types still use `Scout*` in places).

## Session History (What Was Built)

| Pack | Topic | Status |
|------|--------|--------|
| 01 | AES-GCM encrypted store, atomic writes, corruption-tolerant reads | Done |
| 02 | Crash hooks dedupe, safe emit, fatal bypasses batch for emergency webhook | Done |
| 03 | Chrono batch: time window sync, chunked drain, retry timer, re-entry guard | Done |
| 04 | Timed Dio adapter + interceptor waterfall + success/error integration tests | Done |
| 05 | `runtimeVitalsProbe` config fallback for battery/thermal/free RAM | Done |
| 06 | Dispatch policy tests: Wi‑Fi-only, backoff, remote log level | Done |
| — | **1.0.0 production** — config guard, backend guide, network policy | Done |

Details per pack: see `docs/feature-packs/README.md`. Backend: [`docs/BACKEND_INGESTION.md`](BACKEND_INGESTION.md).

## How to Verify Locally

```bash
cd scout_logger
flutter pub get
flutter test
```

## Integration Quick Start (Host App)

```dart
final logger = await ScoutAppLogger.init(
  ScoutLoggerConfig(
    flavor: 'production',
    bulkUploadHandler: (logs) async { /* POST batch */ return true; },
    emergencyWebhookHandler: (log) async { /* POST fatal immediately */ },
    runtimeVitalsProbe: () async => {
      'batteryLevel': 80.0,
      'chargingState': 'charging',
      'thermalState': 'nominal',
      'freeRamBytes': 1024,
    },
  ),
);

dio.attachScoutLogger(logger);

MaterialApp(
  navigatorObservers: [logger.navigatorObserver],
  // ...
);
```

## Mandatory Spec Checklist (Target vs Current)

| # | Requirement | Status |
|---|-------------|--------|
| 1 | `LogEnvelope` matrix (flavor, domain, category, level, metadata) | Done |
| 2 | Dio: trace ID, PII scrub, waterfall timing | Mostly done (stream-based TTFB; not socket-level) |
| 3 | `SmartUIObserver` + FIFO breadcrumbs on errors | Done |
| 4 | Device vitals at crash time | Partial (probe + channel; no built-in native plugin) |
| 5 | `FlutterError` + `PlatformDispatcher` crash hooks | Done |
| 6 | Encrypted storage + chrono batch (50 / 120s) + offline backoff | Done (file AES-GCM, not Isar) |
| 7 | `updateLogLevelsRemote` | Done |
| 8 | Fatal/critical emergency webhook bypass + retry on failure | Done |

## Deferred (by product choice)

- **Store compaction** — rewrite file after skipping corrupted lines.
- **Native vitals plugin** — package stays Dart-only; hosts use `runtimeVitalsProbe` or their own channel.

## Example demo

`example/` — run `cd example && flutter run` for interactive SDK showcase (see `example/README.md`).

## Recommended Next Work (Priority Order)

1. **Crash follow-ups** — optional backup sink; restart-safe pending-crash strategy.
2. **Batch follow-ups** — jittered backoff; persistent retry state across restarts.
3. **Network follow-ups** — chunked streaming tests; platform timing calibration.

## Recently completed

- **v1.0.0 production** — `assertProductionReadyConfig`, `BACKEND_INGESTION.md`, `NetworkLoggingPolicy`, PII scrub expansion, `ScoutAppLogger.log` facade.
- **Pack 06 tests** — Wi‑Fi-only, backoff, remote log level.
- **Emergency dispatch fallback** — `EmergencyDispatchQueue`.

## Key Files

| Area | Path |
|------|------|
| Init / log API | `lib/src/core/scout_logger_manager.dart` |
| Encrypted queue | `lib/src/core/crypto_store.dart` |
| Batch engine | `lib/src/core/batch_engine.dart` |
| Crash hooks | `lib/src/core/crash_hooks.dart` |
| Dio timing | `lib/src/core/timed_http_client_adapter.dart`, `smart_dio_interceptor.dart` |
| Config | `lib/src/config/logger_config.dart` |
| Models | `lib/src/models/log_models.dart` |

## Commit Convention

Keep commits focused per feature pack; reference `docs/feature-packs/NN-*.md` in commit body when applicable.
