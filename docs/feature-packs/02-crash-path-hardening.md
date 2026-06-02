# Pack 2: Crash Path Hardening

## Why this pack

Crash telemetry has the highest urgency. This pack makes crash capture safer and less noisy while preserving emergency dispatch behavior.

## Delivered

- Refactored `CrashHooks` to support injectable crash emitters for deterministic tests.
- Added duplicate-crash suppression window (2 seconds) for identical message+stack signatures.
- Wrapped crash emission in protected async handling so hooks never throw into host app execution.
- Added `uninstall()` to restore previous global error handlers when needed.
- Updated logger immediate path: `FATAL` and `CRITICAL` logs now bypass batch queue and go straight to emergency dispatcher.

## Files changed

- `lib/src/core/crash_hooks.dart`
- `lib/src/core/scout_logger_manager.dart`
- `test/crash_hooks_test.dart`

## Verification

- Unit test confirms duplicate crash suppression behavior within dedupe window.

## Remaining follow-up in this area

- Add optional backup sink when emergency dispatch fails (in addition to encrypted retry queue).
- Add process restart-safe pending-crash persistence strategy for edge crash loops.

## Update (emergency retry queue)

- Failed `notifyEmergency` calls are persisted in `EmergencyDispatchQueue` and retried before batch sync.
