# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.2] - 2026-06-02

### Changed

- Product name **Scout App Logger**; public facade renamed to `ScoutAppLogger` (`SmartEyeLogger` deprecated typedef).

### Added

- Auto app context via `package_info_plus` (`autoResolveAppInfo`).
- Richer device collection via `device_info_plus` + `battery_plus`.
- `LogDispatchPolicy`: batch size/window, per-log mode, Wi‑Fi-only, backoff cap.
- `LogServerRouting`: separate bulk/urgent handlers per log category.
- `EmailReportingConfig` + Gmail preset: plain-text team reports by level.
- Sample incident JSON: `docs/SAMPLE_INCIDENT.json`.

## [0.0.1] - 2026-06-02

### Added

- Initial Scout App Logger SDK (`scout_logger` package).
- `LogEnvelope` schema with flavor, domain, category, level, metadata, breadcrumbs, and device vitals.
- `ScoutAppLogger` / `ScoutLogger` init with encrypted local queue (AES-GCM).
- `SmartUIObserver` navigator breadcrumbs (FIFO, attached on errors and fatals).
- Dio `attachScoutLogger`: trace ID header, PII scrubbing, waterfall timing via `TimedHttpClientAdapter`.
- `FlutterError` and `PlatformDispatcher` crash hooks with dedupe and non-throwing emit path.
- `ChronoBatchEngine`: batch size and time window sync, chunked drain, exponential backoff, Wi‑Fi-only option.
- `updateLogLevelsRemote` for runtime minimum log level.
- Immediate `FATAL` / `CRITICAL` dispatch via `emergencyWebhookHandler`.
- `EmergencyDispatchQueue`: persist and retry failed urgent webhooks before batch sync.
- `runtimeVitalsProbe` config fallback for battery, charging, thermal, and free RAM.
- Unit and integration tests for store, batch engine, crash hooks, Dio, device metrics, and emergency retry.
- `example/` interactive demo app (`scout_logger_demo`) with live handler console.

### Notes

- Dart-only package; no bundled native plugin for system vitals.
- Store compaction and native vitals plugin are intentionally deferred (see `docs/CONTINUATION.md`).

[0.0.1]: https://github.com/alrashidi-approc/scout_logger/releases/tag/v0.0.1
