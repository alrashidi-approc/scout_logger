# Scout App Logger — example demo

Run the interactive showcase:

```bash
flutter pub get
flutter run
```

Pick a device (iOS simulator, Android emulator, macOS, or Chrome).

## What to try

| Action | What it proves |
|--------|----------------|
| **UI trail** | `SmartUIObserver` breadcrumbs across multiple routes |
| **Network OK / err** | Dio interceptor, trace ID, waterfall timing metadata |
| **PII scrub** | `password`, `token`, `email` redacted in network logs |
| **Fill batch** | Encrypted queue + upload when batch size (5) is reached |
| **Error + vitals** | Device vitals + breadcrumb trail on errors |
| **Fatal urgent** | Immediate emergency webhook (skips batch) |
| **Fail urgent** | Failed webhook persisted and retried on next sync |
| **Fail batch** | Backoff when bulk handler returns `false` |
| **Level: warn / debug** | `updateLogLevelsRemote` filtering |

Handler output appears in the on-screen console (your real `bulkUploadHandler` / `emergencyWebhookHandler` wired to the demo hub).
