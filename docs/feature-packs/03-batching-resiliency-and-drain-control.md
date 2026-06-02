# Pack 3: Batching Resiliency and Drain Control

## Why this pack

Offline-first logging must stay stable when queues grow, network flaps, or timers overlap.

## Delivered

- Added sync re-entry guard to prevent overlapping batch uploads.
- Added chunked uploads using `batchSize` as a hard max per request.
- Added force-drain behavior to flush multiple chunks in one sync cycle when needed.
- Added retry timer cancellation/replacement to avoid stacked backoff timers.
- Extended dispose behavior to cancel both periodic and retry timers.

## Files changed

- `lib/src/core/batch_engine.dart`
- `test/chrono_batch_engine_test.dart`

## Verification

- Existing window-based sync test still passes.
- New test verifies force sync drains queue in 2/2/1 chunk pattern.

## Remaining follow-up in this area

- Add jittered backoff for very large fleets.
- Add persistent retry state across app restarts if required by backend SLOs.
