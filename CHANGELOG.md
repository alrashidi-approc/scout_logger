# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`device.deviceName`** (iOS Settings name; Android `brand + model`) and **`device.localizedModel`** (marketing name, e.g. iPhone 16 Pro).
- Android extended: **`product`** in device block when `autoCollectDeviceDetails` is on.
- `runtimeVitalsProbe` may override `deviceName` / `localizedModel`.

## [1.2.0] - 2026-06-03

### Added

- **Issue dedupe & counts:** `IncidentOccurrencePolicy` + in-session tracker — repeats with the same `groupingKey` are not uploaded/emailed until a rollup cooldown; payload includes `triage.occurrence` (`count`, `sinceLastReport`, `firstSeenAt`, `lastSeenAt`, `reportReason`).
- **Smarter urgent email:** shorter alert body, `×N` in subject on repeats, email cooldown per grouping key (default 1h), stack omitted on rollup emails.
- Duplicate **urgent webhook** suppressed after the first fatal per `groupingKey` (rollup still goes to batch).
- **`app.name`** on every incident (and `deployment.appName`) for backend partitioning; set via `BlackboxAppContext.appName`, `ScoutLoggerConfig.blackbox(appName: ...)`, or auto from `PackageInfo.appName`.
- **`customMetadata` on `log()` / `ScoutAppLogger` shortcuts** and **`options.scoutIncidentCustom`** on Dio — app fields always merged into incident `custom`.

### Changed

- **NETWORK incidents:** Dio/network fields only in `network.triggering`; `custom` holds `globalMetadata` + app `customMetadata` (no duplicate trace/path/waterfall).

## [1.1.0] - 2026-06-03

### Added

- **Simple log API:** `logger.info/error/warn/fatal/...` and `ScoutAppLogger.error(...)` shortcuts (defaults: internal + logic).
- **Product insights (schema 1.2):** `triage.fingerprint`, `triage.groupingKey`, `triage.tags`, `triage.contexts`.
- `deployment.release` / `deployment.environment` and `session` metadata on incidents.
- `ProductInsightsPolicy`: sampling, per-session cap, `beforeIncidentSend`, lifecycle breadcrumbs.
- `ScoutLogger.setTag`, `setContext`, `breadcrumb`, and `ScoutAppLogger` facade helpers.

## [1.0.0] - 2026-06-03

### Added

- `NetworkLoggingPolicy`: `NetworkLogScope.all` vs `errorsOnly`, configurable `nonErrorStatusCodes` (default `{401}`).
- Production `init` validation: unique `encryptionKey` required for production/staging flavors; minimum key length 16.
- `docs/BACKEND_INGESTION.md` for backend/SRE teams (schema, trace correlation, PII notes).
- `ScoutAppLogger.log` and `ScoutAppLogger.updateLogLevelsRemote` on the public facade.
- Expanded PII scrub keys (`secret`, `api_key`, `bearer`, `otp`, …).

### Changed

- **1.0.0** stable release; `app.sdkVersion` in incidents matches package version.
- Example app refactored to clean architecture (`core/` + `features/demo/`).

### Removed

- `battery_plus` from the SDK (use host `runtimeVitalsProbe`; example app uses `battery_plus` locally).

## [0.0.2] - 2026-06-02

### Changed

- Product name **Scout App Logger**; public facade renamed to `ScoutAppLogger` (`SmartEyeLogger` deprecated typedef).

### Added

- Auto app context via `package_info_plus` (`autoResolveAppInfo`).
- Richer device collection via `device_info_plus` + optional `runtimeVitalsProbe` for battery.
- `LogDispatchPolicy`: batch size/window, per-log mode, Wi‑Fi-only, backoff cap.
- `LogServerRouting`: separate bulk/urgent handlers per log category.
- `EmailReportingConfig` + Gmail preset: plain-text team reports by level.
- Sample incident JSON: `docs/SAMPLE_INCIDENT.json`.

## [0.0.1] - 2026-06-02

### Added

- Initial Scout App Logger SDK (`scout_logger` package).
- Encrypted queue, crash hooks, Dio interceptor, batch engine, emergency queue.

[1.2.0]: https://github.com/alrashidi-approc/scout_logger/releases/tag/v1.2.0
[1.1.0]: https://github.com/alrashidi-approc/scout_logger/releases/tag/v1.1.0
[1.0.0]: https://github.com/alrashidi-approc/scout_logger/releases/tag/v1.0.0
[0.0.2]: https://github.com/alrashidi-approc/scout_logger/releases/tag/v0.0.2
[0.0.1]: https://github.com/alrashidi-approc/scout_logger/releases/tag/v0.0.1
