# Pack 5: Vitals Completeness with Runtime Probe

## Why this pack

Some hosts cannot provide battery/thermal/free-RAM values through the default channel at all times. This pack adds a fallback path so crash vitals stay populated.

## Delivered

- Added `RuntimeVitalsProbe` to config for host-provided live vitals.
- Wired probe into `DeviceVitalsCollector`.
- Collector now merges values in this order:
  1. platform channel data
  2. runtime probe data
  3. safe null/default fallback

## Files changed

- `lib/src/config/logger_config.dart`
- `lib/src/core/device_metrics.dart`
- `lib/src/core/scout_logger_manager.dart`
- `test/device_metrics_test.dart`

## Verification

- New unit test confirms probe values are used when channel data is unavailable.

## Remaining follow-up in this area

- Native plugin implementation can still be added for richer thermal granularity per OS.
