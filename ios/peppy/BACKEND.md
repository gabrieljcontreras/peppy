# Peppy Onboarding Backend Integration Contract

Status: proposed contract for the iOS MVP. This document defines future backend work; it does not describe an API that the current app can call yet.

## Conventions

- Base path: `/api/v1`.
- JSON keys and enum values use `snake_case`.
- Dates use UTC ISO 8601 strings, for example `2026-06-14T18:00:00Z`.
- Height and weight are stored in metric units. Preferred units are display preferences only.
- All endpoints require `Authorization: Bearer <access_token>` and resolve the user from the token. A user ID is never accepted from the request body.
- Responses use `Content-Type: application/json`. `PATCH` uses JSON Merge Patch semantics.
- The server owns `updated_at`; clients must not advance it themselves.

## Profile Resource

Schema version 1 is the first server representation of the completed or partially completed iOS onboarding draft.

```json
{
  "schema_version": 1,
  "age": 32,
  "height_cm": 172.72,
  "preferred_height_unit": "ft_in",
  "weight_kg": 74.84,
  "preferred_weight_unit": "lb",
  "peptides": ["Retatrutide"],
  "custom_peptides": [],
  "other_medications": null,
  "workout_days_per_week": 3,
  "goals": ["track_protocols", "see_what_works"],
  "custom_goal": null,
  "healthkit": {
    "requested": true,
    "last_sync_at": null
  },
  "notifications": {
    "authorized": true
  },
  "updated_at": "2026-06-14T18:00:00Z"
}
```

### Fields and validation

| Field | Rules |
| --- | --- |
| `schema_version` | Required integer. MVP accepts `1`. |
| `age` | Nullable integer from 13 through 120. |
| `height_cm` | Nullable decimal from 100 through 250. Preserve at least two decimal places. |
| `preferred_height_unit` | Nullable enum: `ft_in`, `cm`. It is only meaningful when `height_cm` is present. |
| `weight_kg` | Nullable decimal from 27 through 318. Preserve at least two decimal places. |
| `preferred_weight_unit` | Nullable enum: `lb`, `kg`. It is only meaningful when `weight_kg` is present. |
| `peptides` | Array of canonical catalog names. Trim whitespace and deduplicate case-insensitively. No dosage data is accepted here. |
| `custom_peptides` | Array of non-catalog names, each 1–80 characters after trimming; maximum 20 values. Deduplicate across both peptide arrays. |
| `other_medications` | Nullable trimmed string, maximum 200 characters. Empty strings normalize to `null`. |
| `workout_days_per_week` | Nullable integer from 0 through 7. |
| `goals` | Unique values from `track_protocols`, `understand_body`, `build_habits`, `see_what_works`, `optimize_recovery`, `feel_in_control`. |
| `custom_goal` | Nullable trimmed string, maximum 200 characters. Empty strings normalize to `null`. |
| `healthkit` | Nullable object. `requested` records whether the native request was attempted, not whether every read type was granted. `last_sync_at` is server-maintained. |
| `notifications` | Nullable object. `authorized` is the last status observed by the app and may become stale when changed in Settings. |
| `updated_at` | Server-generated resource revision timestamp. Returned on reads and writes. |

The iOS-to-server enum mapping is:

| iOS value | API value |
| --- | --- |
| `feetAndInches` | `ft_in` |
| `centimeters` | `cm` |
| `pounds` | `lb` |
| `kilograms` | `kg` |
| `trackProtocols` | `track_protocols` |
| `understandBody` | `understand_body` |
| `buildHabits` | `build_habits` |
| `seeWhatWorks` | `see_what_works` |
| `optimizeRecovery` | `optimize_recovery` |
| `feelInControl` | `feel_in_control` |

### Missing, empty, and skipped answers

- A missing key in `PATCH` means “leave unchanged.”
- An explicit `null` in `PATCH` clears a nullable scalar or nested permission object.
- `PUT` is a full replacement: omitted nullable scalars become `null` and omitted arrays become `[]`.
- `[]` means no selected values and is not equivalent to an omitted key in `PATCH`.
- A partial draft may contain any subset of nullable answers. Validation applies only to supplied values.
- The attach envelope reports `is_complete` and `current_step`. In a completed draft, an absent optional answer is treated as skipped. The server records that answer state in audit metadata even though the public profile value is `null` or `[]`.
- Personalization consumers must treat absent or skipped data as “no signal.” They must not infer a negative medical fact.

## Endpoints

### `GET /api/v1/profile/onboarding`

Returns the authenticated user's server profile.

- `200`: profile returned with an `ETag` header.
- `401`: token missing, expired, or invalid.
- `404`: no server profile exists yet. The iOS app may then attach its local draft.

### `PUT /api/v1/profile/onboarding`

Creates or fully replaces the resource using the profile JSON above.

- Create requests omit `updated_at`; successful creation returns `201`.
- Replacements send `If-Match: <etag from the latest GET or write>` and may echo the corresponding `updated_at`.
- Successful replacement returns `200`, a fresh `updated_at`, and a fresh `ETag`.
- A missing precondition on an existing resource returns `400`.

### `PATCH /api/v1/profile/onboarding`

Updates only supplied fields. Example:

```http
PATCH /api/v1/profile/onboarding
Authorization: Bearer <access_token>
Content-Type: application/merge-patch+json
If-Match: "onboarding-profile-revision"

{
  "weight_kg": 73.94,
  "preferred_weight_unit": "lb",
  "goals": ["track_protocols", "optimize_recovery"]
}
```

An existing resource requires the latest `If-Match` value. Success returns `200` with the complete updated resource.

### `POST /api/v1/profile/onboarding/attach`

Associates the device-local anonymous draft after registration or sign-in. It is the only endpoint allowed to accept local draft metadata.

```http
POST /api/v1/profile/onboarding/attach
Authorization: Bearer <access_token>
Idempotency-Key: 6f3950d8-5aa8-4476-a2eb-2c967196cff9
Content-Type: application/json

{
  "schema_version": 1,
  "draft_id": "6f3950d8-5aa8-4476-a2eb-2c967196cff9",
  "draft_created_at": "2026-06-14T17:30:00Z",
  "draft_updated_at": "2026-06-14T17:59:00Z",
  "is_complete": true,
  "current_step": "notifications",
  "profile": {
    "age": 32,
    "height_cm": 172.72,
    "preferred_height_unit": "ft_in",
    "weight_kg": 74.84,
    "preferred_weight_unit": "lb",
    "peptides": ["Retatrutide"],
    "custom_peptides": [],
    "other_medications": null,
    "workout_days_per_week": 3,
    "goals": ["track_protocols", "see_what_works"],
    "custom_goal": null,
    "healthkit": { "requested": true },
    "notifications": { "authorized": true }
  }
}
```

Idempotency behavior:

1. iOS creates one stable UUID for an attachment attempt and persists it with the local draft.
2. The server scopes the key to the authenticated user and route and stores the request hash and response for at least seven days.
3. Repeating the same key and body returns the original status and response without another write.
4. Reusing the key with a different body returns `409 idempotency_key_reused`.
5. iOS clears the anonymous draft only after a successful response has been persisted as the user-associated profile.

If no server profile exists, attach creates it and returns `201`. If a profile exists, the server may fill fields that are still empty, but it must never silently replace a nonempty server value with a different local value. Differing nonempty values return `409 profile_conflict` with the current server resource. iOS preserves the local draft until the conflict is resolved; the server profile remains the active cross-device value.

## Concurrency and Errors

`updated_at` is a server revision, not a client event timestamp. Every successful mutation assigns a strictly newer UTC value and changes the `ETag`. `PUT` and `PATCH` compare `If-Match` atomically before writing. A stale revision returns `409`; the client must fetch the latest resource and deliberately merge or retry. Last-write-wins is not permitted for health profile data.

Error responses use one envelope:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "One or more fields are invalid.",
    "fields": {
      "age": ["Must be between 13 and 120."]
    },
    "request_id": "req_01J0Example"
  }
}
```

| Status | Meaning |
| --- | --- |
| `200` | Read, replacement, patch, attach replay, or no-conflict attach succeeded. |
| `201` | A profile was created by `PUT` or attach. |
| `400` | Malformed JSON, missing required header, or invalid request shape. |
| `401` | Authentication failed. The client may use its existing refresh-token flow once. |
| `404` | No profile exists for `GET`. |
| `409` | Stale revision, conflicting attachment, or idempotency-key reuse. Includes the current revision when applicable. |
| `422` | Syntactically valid request failed field, enum, range, or schema-version validation. |

## Schema Migration

- The server stores the latest canonical schema and retains the source schema version in audit metadata.
- iOS schema 1 maps local metric values directly and translates enums using the table above. Empty optional strings become `null`.
- During rollout, the server accepts the current schema and at least one previous supported schema, then migrates in one transaction before validation and persistence.
- Unsupported future or retired versions return `422 unsupported_schema_version` with `minimum_supported_version` and `current_version`.
- A failed migration performs no partial write. The local draft remains available for retry.
- A response always uses the server's current schema. iOS must preserve unknown response fields when possible and must not upload a newer schema until the app knows how to encode it.

## Personalization Consumers

Onboarding data is preference and context data. A selected peptide does not create a protocol, establish a prescription, or authorize dosage guidance.

| Consumer | MVP use | Later recommendation |
| --- | --- | --- |
| Dashboard | Use goals, selected peptides, and workout frequency to order relevant cards and empty states. | Learn card ranking from explicit feedback and observed engagement. |
| Check-ins | Use selected peptides and goals to suggest relevant non-clinical check-in prompts. | Adapt prompts using protocol events and longitudinal trends. |
| Protocol creation | Prefill peptide search with selected names only after the user starts creation. | Suggest templates reviewed for safety; never create or activate automatically. |
| Insights | Use units and goals for display and topic relevance. Do not produce causal or clinical claims from onboarding alone. | Combine consented longitudinal data with transparent confidence and provenance. |
| Reminders | Use workout frequency and active protocols only after the user explicitly configures reminder timing. | Recommend schedules while requiring confirmation before activation. |
| Connected health | Show connection state and trigger sync only after permission and account association. | Support additional providers and richer source-quality metadata. |
| Exports | Include all profile fields, answer states, provenance, consent history, and server timestamps. | Add machine-readable interoperability formats. |
| Account deletion | Delete every field and dependent personalization artifact. | Support user-selected category deletion before full account deletion. |

MVP consumers must tolerate a missing profile and every field being absent. Peptide names, medication text, HealthKit data, and goals must not be used for advertising or sold to third parties.

## Privacy, Consent, and Provenance

### Consent records

The backend stores an append-only consent event for HealthKit and notifications containing user ID, installation ID, permission type, onboarding choice (`requested` or `skipped`), app-observed outcome, event timestamp, app version, and request ID. A newer OS status observation does not rewrite the original consent event.

HealthKit does not reliably disclose read authorization for every requested type. The backend must distinguish “request attempted” from “data observed” and must not label all read types as granted. Notification authorization is also an observation that can change in Settings.

### Field provenance and auditability

Each mutable profile field records its source (`onboarding_ios`, `profile_edit`, `healthkit`, `backend_import`, or `support_correction`), source timestamp, actor, request ID, and schema version. The audit log records field names and change metadata without placing raw health values in ordinary application logs. Access to profile, consent, export, and deletion operations is auditable.

### HealthKit ingestion

HealthKit samples are stored separately from the onboarding profile. Each accepted sample records type, normalized unit/value, start/end time, source bundle identifier, source version, device metadata when available, and the HealthKit sample UUID. Enforce a unique key on user, sample type, and sample UUID so retries are idempotent. Process HealthKit deletions and revisions, not only inserts.

Sync cursors are opaque, encrypted at rest, scoped to user, installation, and sample type, and advanced only after the corresponding batch commits. `last_sync_at` is updated after a successful committed sync. Disconnect or consent withdrawal stops future ingestion; user-requested connected-health deletion removes samples, cursors, and derived artifacts.

### Notifications and devices

Use the existing notification resources:

- `POST /api/v1/notifications/devices` registers or refreshes an APNs token with an installation ID, platform, environment, app version, and last-seen timestamp.
- `DELETE /api/v1/notifications/devices/{id}` unregisters that installation.
- `GET` and `PATCH /api/v1/notifications/preferences` read and update account-level preferences.

APNs tokens are installation credentials, not profile fields. Upsert tokens idempotently, rotate them when iOS supplies a new value, and prevent one active token from belonging to multiple users. Preferences restore across devices; authorization status remains device-specific. Logout unregisters or disassociates that installation without deleting account preferences. Reinstall creates a new installation record and retires stale tokens after delivery feedback or an inactivity window.

## Data Lifecycle

- **Logout:** remove local credentials, unregister or disassociate the device token, stop HealthKit upload, and retain the authenticated user's server profile for future sign-in. Anonymous local drafts are not uploaded without a new authenticated attach request.
- **Reinstall/new device:** after sign-in, `GET` restores the server profile and account-level notification preferences. The new installation requests device permissions independently and registers its own token and HealthKit cursor.
- **Export:** include the profile, schema history, answer states, consent events, provenance, notification preferences, connected-health records, and timestamps in a portable archive.
- **Deletion:** account deletion atomically schedules removal of the profile, local-draft attachments, personalization outputs, HealthKit samples/cursors, notification tokens/preferences, and exports. Backups expire under the documented retention policy. Retained compliance tombstones contain only the minimum non-health metadata and expiry date.
- **Partial deletion:** the MVP must support disconnecting and deleting connected-health data independently of account deletion.

## Delivery Scope

### Required for MVP backend integration

- Profile storage, validation, schema migration, and authenticated `GET`/`PUT`/`PATCH`.
- Idempotent local-draft attachment with deterministic conflict responses.
- Revision/ETag concurrency control and the standard error envelope.
- Field provenance, consent events, export, account deletion, and connected-health deletion.
- Device-token registration, preference synchronization, logout cleanup, and cross-device profile restoration.
- HealthKit cursoring, sample deduplication, revisions, and deletions before raw samples are uploaded.

### Deferred enhancements

- Learned personalization ranking.
- Proactive protocol templates or reminder recommendations.
- Additional wearable providers and interoperability export formats.
- User-facing field-by-field merge and selective data-category deletion.
- Automated clinical interpretations. Any future clinical behavior requires separate safety, regulatory, and product review.
