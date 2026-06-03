# Backend ingestion guide (Scout App Logger)

This document is for **backend / SRE / on-call** engineers consuming mobile incidents.

## Transport

| Path | When | Payload |
|------|------|---------|
| **Batch** | `onBatchIncidents` / `onBatchIncidents` blackbox | `List<String>` — each string is one **incident JSON** document |
| **Urgent** | `onUrgentIncident` | Single incident JSON string (`FATAL`, `CRITICAL`, or `immediateDispatch`) |

Return `true` from batch handler only after durable server-side accept. Failed batch → SDK retries with exponential backoff.

## Schema

- **Version field:** `schemaVersion` (current: `1.1`)
- **SDK field:** `app.sdkVersion` (package version, e.g. `1.0.0`)
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
| `app.flavor` | `production`, `staging`, `dev` |
| `network.triggering.traceId` | **Same value as `X-Trace-ID`** on the failing HTTP call |
| `network.triggering.statusCode` | HTTP status when category is `NETWORK` |
| `screen.userFlow` | Ordered UI breadcrumbs before the incident |
| `device.*` | OS, model, RAM, battery (see below) |

## Correlating with server logs

1. Read `network.triggering.traceId` (or `custom.traceId` on network errors).
2. Match against API gateway / service logs using the same header the app sent: **`X-Trace-ID`**.
3. Use `network.triggering.waterfallUs` or `networkWaterfallSec` for latency breakdown (TTFB vs download).

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
