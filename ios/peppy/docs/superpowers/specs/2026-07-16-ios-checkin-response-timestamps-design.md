# iOS Check-in Response Timestamp Design

## Problem

The check-in POST request succeeds and the backend commits the new row, but the iOS app can fail while decoding the returned `CheckinResponse`. The local SQLite backend serializes `created_at` and `updated_at` as ISO-8601-like timestamps without a timezone. `Checkin` currently delegates both fields to `JSONDecoder`'s strict `.iso8601` strategy, which rejects that representation. The user therefore sees “Failed to process server response,” while a second submission correctly finds the already-persisted check-in and returns a duplicate conflict.

## Scope

This change is limited to the iOS `Checkin` response model and its decoding tests. It will not change backend persistence, duplicate-check behavior, global API date decoding, check-in form fields, or other API models.

## Design

`Checkin` will decode `created_at` and `updated_at` through a model-local timestamp parser. The parser will accept all response formats Peppy currently encounters:

- ISO-8601 timestamps with a timezone, with or without fractional seconds.
- SQLite-style ISO-8601 timestamps without a timezone, with or without fractional seconds.
- `null` or missing timestamps, preserving the fields' existing optional semantics.

Timezone-less SQLite timestamps will be interpreted as UTC. This matches the backend's use of server-generated timestamps and avoids device-timezone-dependent results.

The parser will remain private to `Checkin` so the fix has the smallest possible blast radius. Existing date-only decoding for the check-in's `date` field remains unchanged.

## Data Flow

1. The check-in form submits `POST /checkins` as it does today.
2. The backend persists the row and returns `CheckinResponse` with `created_at` and `updated_at`.
3. The iOS `Checkin` model decodes both timestamps using the tolerant parser.
4. `CheckinViewModel.save()` receives the decoded model and returns `true`.
5. `CheckinView` calls `onSaved()` and dismisses, so the user sees a single smooth successful submission.

## Error Handling

If either timestamp is present but does not match any supported representation, decoding will still fail and the existing “Failed to process server response” message will remain. Genuine HTTP, authorization, validation, and duplicate-check errors remain unchanged. The fix will not hide malformed server data or treat an HTTP failure as a successful save.

## Testing

Regression tests will decode realistic complete `Checkin` response bodies and verify both `created_at` and `updated_at`:

- SQLite-style timezone-less timestamps decode successfully and are interpreted as UTC.
- Timezone-aware timestamps with fractional seconds decode successfully.
- `null` timestamps remain `nil`.
- A malformed non-null timestamp still throws a decoding error.

The existing check-in request and save tests will continue to verify request encoding and the successful view-model path.

## Success Criteria

- A locally persisted check-in no longer displays a response-processing error.
- The first successful submission returns `true`, invokes the normal saved callback, and dismisses the form.
- Both `created_at` and `updated_at` decode consistently across local SQLite and timezone-aware backend responses.
- Duplicate submissions and genuine failures continue to surface as errors.
