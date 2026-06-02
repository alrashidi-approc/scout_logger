# Pack 1: Encrypted Persistence and Queue Integrity

## Why this pack

This pack hardens the most critical responsibility of the SDK: never lose logs before upload.

## Delivered

- Migrated local log encryption to authenticated AES-GCM via `cryptography`.
- Added serialized operation locking in `EncryptedLogStore` to prevent overlapping writes.
- Added atomic file writes (`.tmp` then rename) to reduce partial-write corruption risk.
- Added tolerant read behavior: corrupted records are skipped instead of crashing the queue.
- Added `deviceVitals` restore during store deserialization.
- Added configurable storage path to make tests isolated and deterministic.

## Files changed

- `lib/src/core/crypto_store.dart`
- `pubspec.yaml`
- `test/encrypted_log_store_test.dart`

## Verification

- Round-trip test verifies encrypted write/read and vitals restoration.
- Corruption test verifies malformed records are ignored while valid records remain readable.

## Remaining follow-up in this area

- Optional compaction task to proactively rewrite file after detecting corrupted rows.
- Optional migration strategy if legacy encrypted lines must be read after algorithm change.
