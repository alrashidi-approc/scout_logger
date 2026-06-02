# Pack 4: Network Waterfall and Error Signal Quality

## Why this pack

Network logs must provide high-quality timing + safe payload context in both success and failure paths.

## Delivered

- Added integration test coverage for failure path metadata shape and timing values.
- Verified error logs include `waterfallUs` with stable semantics (`startedAt`, `firstByteAt`, `ttfb`, `payloadDownload`, `total`).
- Verified recursive PII scrubbing for both request and response payloads in error logs.

## Files changed

- `test/smart_dio_interceptor_integration_test.dart`

## Verification

- Success-path integration test remains passing.
- New error-path integration test validates timing and `[REDACTED]` fields.

## Remaining follow-up in this area

- Optional adapter-level coverage for chunked streaming with large payloads.
- Optional platform-specific timing calibration for edge transport behavior.
