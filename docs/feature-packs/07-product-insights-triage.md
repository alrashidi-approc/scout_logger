# 07 — Product insights & triage

## Goal

Give internal apps Sentry-like **grouping and scope** without a hosted platform — backend can dedupe, filter, and analyze releases.

## Added

- `triage.fingerprint` + `triage.groupingKey` on every incident (schema **1.2**).
- `deployment.release` / `deployment.environment`.
- `session.startedAt` / `session.incidentIndex`.
- `IncidentScope`: `setTag`, `setContext`, `clearScope`.
- `ScoutLogger.breadcrumb()` for business steps.
- `ProductInsightsPolicy`: `sampleRate`, `maxIncidentsPerSession`, `beforeIncidentSend`, `trackAppLifecycle`.
- `ScoutLifecycleBinding` → `APP_RESUMED` / `APP_PAUSED` breadcrumbs.

## Verify

```bash
flutter test test/incident_fingerprint_test.dart test/product_insights_incident_test.dart
```
