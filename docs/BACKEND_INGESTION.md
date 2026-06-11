# Backend ingestion guide (Scout App Logger)

This document is for **backend / SRE / on-call** engineers consuming mobile incidents.

## Transport

| Path | When | Payload |
|------|------|---------|
| **Batch** | `onBatchIncidents` / `onBatchIncidents` blackbox | `List<String>` — each string is one **incident JSON** document |
| **Urgent** | `onUrgentIncident` | Single incident JSON string (`FATAL`, `CRITICAL`, or `immediateDispatch`) |

Return `true` from batch handler only after durable server-side accept. Failed batch → SDK retries with exponential backoff.

## Schema

- **Version field:** `schemaVersion` (current: `1.2`)
- **SDK field:** `app.sdkVersion` (package version, e.g. `1.2.0`)
- **Canonical sample:** [`SAMPLE_INCIDENT.json`](SAMPLE_INCIDENT.json)

### Top-level map (what to index)

| Field | Use for |
|-------|---------|
| `incidentId` | Idempotency / dedupe (client-generated microsecond id) |
| `timestamp` / `time.utc` | Event time (UTC ISO-8601) |
| `time.local` | User-local wall time for support tickets |
| `event.level` | `DEBUG` … `CRITICAL` — alert routing |
| `event.category` | `NETWORK`, `SYSTEM_CRASH`, `LOGIC`, … |
| `event.message` | Human-readable summary |
| `user.userId` / `user.sessionId` | Correlate with your auth/session store |
| `app.name` | **Partition key** — human-readable app label (same value as `deployment.appName`) |
| `app.packageName` | Store / bundle id (e.g. `com.company.shop`) |
| `app.flavor` | `production`, `staging`, `dev` |
| `deployment.appName` | Duplicate of `app.name` for pipelines that index on `deployment` |
| `network.triggering.traceId` | **Same value as `X-Trace-ID`** on the failing HTTP call |
| `triage.groupingKey` | Stable SHA-256 for dedupe / “same issue” dashboards |
| `triage.occurrence.count` | How many times this `groupingKey` fired this session (rollup reports total) |
| `triage.occurrence.sinceLastReport` | New hits since the previous upload for this key |
| `triage.occurrence.reportReason` | `first` \| `rollup` — use to avoid treating rollups as new issues |
| `triage.fingerprint` | Human-readable components (category, message, top frame, tags) |
| `triage.tags` / `triage.contexts` | Host-defined scope (`setTag`, `setContext`) |
| `deployment.release` | e.g. `com.app@2.4.1+204` — regression by build |
| `deployment.environment` | e.g. `production`, `staging` |
| `session.incidentIndex` | Nth incident in this app session |
| `network.triggering.statusCode` | HTTP status when category is `NETWORK` |
| `screen.userFlow` | Ordered UI breadcrumbs before the incident |
| `device.*` | OS, model, RAM, battery (see below) |

## Device fields (`device` block)

| Field | Meaning |
|-------|---------|
| `deviceName` | **Human label** — iOS: name from Settings (e.g. “Mahmoud’s iPhone”); Android: `brand + model` |
| `localizedModel` | **Marketing model** — iOS: e.g. “iPhone 16 Pro”; Android: `model` |
| `deviceModel` | Technical id — iOS: `iPhone17,1`; Android: model string |
| `manufacturer` | e.g. Apple, Google, Samsung |
| `osVersion` | OS release (e.g. `18.6`, `14`) |
| `platform` | `ios` / `android` |
| `ramUsedBytes` / `ramFreeBytes` | App RSS; free RAM needs `runtimeVitalsProbe` |
| `batteryLevel` | 0.0–1.0 via probe |
| `chargingState` / `thermalState` | Via probe |
| `isPhysicalDevice` | `false` = simulator/emulator |
| `identifierForVendor` | iOS IDFV (extended details) |
| `androidSdkInt`, `brand`, `product`, `supportedAbis` | Android extended details |

**Privacy:** `deviceName` on iOS may contain the user’s real name — treat as PII in storage/retention.

## Correlating with server logs

1. Read `network.triggering.traceId` for network errors (`custom` does not repeat Dio fields).
2. App-only fields live in `custom` via `customMetadata` on `log()`, `setGlobalMetadata`, or Dio `options.scoutIncidentCustom`.
3. Match against API gateway / service logs using the same header the app sent: **`X-Trace-ID`**.
4. Use `network.triggering.waterfallUs` or `networkWaterfallSec` for latency breakdown (TTFB vs download).

## Device battery field

- `device.batteryLevel` is a **fraction 0.0–1.0** (e.g. `0.42` = 42%).
- `device.chargingState` comes from the host `runtimeVitalsProbe` (e.g. `charging`, `discharging`).

## PII

Request/response bodies in network metadata are **scrubbed on device** (`password`, `token`, `authorization`, `email`, … → `[REDACTED]`). Do not log raw incident JSON into public tools without a data policy.

## Payload size control

`payload.detailLevel` and `payload.sectionsIncluded` describe what the client included (see `IncidentSharingPolicy`). Minimal payloads may omit `device`, `screen.userFlow`, or `stackTrace`.

## Recommended server handling

1. **Parse** JSON; reject unknown `schemaVersion` with metric, not silent drop.
2. **Store** raw JSON + indexed fields (`incidentId`, `userId`, `level`, `traceId`, `timestamp`).
3. **Alert** on `FATAL` / `CRITICAL` urgent path with paging; batch `ERROR` for dashboards.
4. **Ignore** client `DEBUG`/`INFO` in batch unless you explicitly enable full network logging (`NetworkLogScope.all`).

## Client production checklist

See [README.md](../README.md#production-checklist) — encryption key, `runtimeVitalsProbe`, `bindUser`, Dio attach, network policy.
