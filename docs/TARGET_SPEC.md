# Target Specification (Product Requirements)

Canonical requirements for the Smart Eye Logger SDK. Implementation progress is tracked in `docs/feature-packs/` and `docs/CONTINUATION.md`.

## 1. Unified Log Schema

Every log is a `LogEnvelope` with:

- Dynamic **flavor** string (`dev`, `staging`, `production`, …)
- **Domain:** `EXTERNAL` (remote APIs/infra) vs `INTERNAL` (app/UI/logic)
- **Category:** `UI`, `NETWORK`, `SECURE_STORAGE`, `SYSTEM_CRASH`, …
- **Level:** `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`, `CRITICAL`
- **metadata:** `Map<String, dynamic>`

## 2. Smart Network Interceptor (Dio)

- TTFB + waterfall timestamps in metadata
- Auto `X-Trace-ID` UUID header
- Recursive PII scrub: `password`, `token`, `authorization`, `card_number`, `cvv`, `email`, `phone` → `[REDACTED]`

## 3. UI Navigation Tracker

- `SmartUIObserver` extends `NavigatorObserver`
- FIFO breadcrumbs (default max 50)
- On `ERROR` / `FATAL` / `CRITICAL`: deep-copy full breadcrumb trail into envelope

## 4. Device & System Vitals

At exception/crash time: OS, model, manufacturer, RAM used/free, battery, charging/thermal.

## 5. Advanced Crash Hooking

- `FlutterError.onError`
- `PlatformDispatcher.instance.onError`
- `Domain.INTERNAL`, `FATAL`, stack trace, breadcrumbs, immediate dispatch

## 6. Encrypted Storage & Chrono-Batching

- Encrypted local persistence (not raw plaintext files)
- Batch upload when count ≥ 50 **or** 120s since last sync
- Offline-first: connectivity check, exponential backoff, optional Wi-Fi-only

## 7. Dynamic Remote Configuration

- `updateLogLevelsRemote(minimumLevel:, userId:)` shifts active threshold at runtime

## 8. Urgent Outbound Notifier

- `FATAL` / `CRITICAL` bypass batch queue → emergency webhook immediately

## Technical Constraints

- No UI blocking: encryption/serialization off main thread where possible (isolates/async)
- Clean public surface: `SmartEyeLogger.init`, Dio extension, `navigatorObserver`
- Allowed deps: `dio`, `crypto`, `cryptography`, `uuid`, `device_info_plus`, `connectivity_plus`
