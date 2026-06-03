# 06 — Dispatch policy & remote level tests

## Goal

Cover the top gaps from `docs/CONTINUATION.md`: Wi‑Fi-only gating, exponential backoff on failed batch upload, and `updateLogLevelsRemote` filtering.

## Changes

- Injectable `ConnectivityChecker` on `NetworkDispatcher` and optional `ScoutLoggerConfig.connectivityChecker` for tests.
- Optional `queueStoragePath` / `emergencyStoragePath` on config for isolated test queues.
- `ScoutLogger.resetForTesting()` to dispose timers and clear the singleton between tests.

## Tests

| File | Behavior |
|------|----------|
| `test/network_dispatcher_test.dart` | Offline, Wi‑Fi-only, cellular allowed |
| `test/chrono_batch_engine_test.dart` | Backoff retry (2s), sync deferred when `canSyncNow` is false |
| `test/remote_log_level_test.dart` | Remote min level drops info after raise to WARN |

## Verify

```bash
flutter test
```
