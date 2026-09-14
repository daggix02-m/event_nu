# Push Notifications — Device Registration + FCM Dispatch (Phase 17)

The backend registers client devices (FCM tokens), then a worker dispatches the
existing `notifications` inbox rows and due `event_reminders` to those devices
through Firebase Cloud Messaging (FCM v1 HTTP API).

- **Locked**: Phase 17 (2026-09-14). Provider abstraction (`noop`/`fcm`),
  notification + reminder dispatch queues with lease-based claiming, invalid
  token pruning, exponential backoff. APNs/iOS and Flutter UI are later phases.
- **Spec source**: `EVENT_NU_IMPLEMENTATION_DOCUMENTATION_v3.md` §14.1/§14.2.

## Device registry

| Endpoint | Auth | Behavior |
|---|---|---|
| `POST /api/v1/devices` | Bearer (`protectedIdem`) | Upserts the device token for the caller → 201 `{data: device}`. Idempotent. |
| `GET /api/v1/me/devices` | Bearer | Lists the caller's devices (newest first). |
| `DELETE /api/v1/devices/{id}` | Bearer | Deregisters the caller's device; idempotent (another user's id is a no-op). Malformed id → 404 before any DB access. |

Body: `{"token": "<fcm-token>", "platform": "android|ios|web"}` — `platform`
defaults to `android`; token must be non-empty and ≤ 4096 chars (422 otherwise).

- One device = one token: `token` is `UNIQUE`. A re-login on the same phone
  reassigns the row to the new user (`last_seen_at` refreshed, platform
  updated, same `id`) — the old owner stops receiving pushes.
- Registration runs through the SECURITY DEFINER `upsert_user_device`
  (**migration 00019**). The `ON CONFLICT (token) DO UPDATE` path may touch
  another user's row, which `app_user` RLS forbids — so, like `notify_user`,
  the helper owns its rows. It returns the freshly upserted row via
  `RETURN QUERY … RETURNING` because a plain `SELECT` *cannot* read a row its
  own subquery just inserted (the outer statement's snapshot precedes the
  write).
- RLS (`user_devices_own`) keeps reads/delete scoped to `current_app_user_id()`
  or the privileged service role; the push consumer runs under `service`.

## Dispatch queue

`notifications` gained `dispatch_attempts`, `dispatched_at`,
`next_dispatch_at` (default `now()`, so legacy inbox rows become claimable),
and `dispatch_lease_at`. `event_reminders` gained `dispatch_lease_at`. The
worker polls two queues with the same lease pattern as the email outbox:

1. `ClaimForDispatch` — `UPDATE … SET dispatch_lease_at = now()+lease WHERE id IN
   (… WHERE dispatched_at IS NULL AND next_dispatch_at <= now() AND lease expired
   ORDER BY created_at,id LIMIT n FOR UPDATE SKIP LOCKED) RETURNING …`.
2. `ClaimDue` — same, over `event_reminders WHERE status='scheduled' AND
   remind_at <= now()`.

A crash mid-send leaves the row leased; after the lease expires it is reclaimed
(at-least-once). Batch size and poll interval are config-tunable.

### Notification dispatch (`PushConsumer.processNotifications`)

- Load all devices for the recipient; **no devices → `MarkDispatched`** (stay
  out of the queue; the inbox row remains for in-app display).
- `CodeInvalidToken` (FCM: `UNREGISTERED`/`INVALID_ARGUMENT`/
  `SENDER_ID_MISMATCH`/`NOT_FOUND`) → prune the device
  (`DeleteByToken`) and treat the notification as delivered.
- `CodeUnavailable` (transient) → `MarkDispatchFailed(attempt+1, now +
  base*2^min(attempt-1,6))`.
- Attempts exhausted (`PUSH_MAX_ATTEMPTS`, default 5) → `MarkDispatched`
  (give up; the inbox row remains readable).
- Success → `MarkDispatched`.

### Reminder dispatch (`processReminders`)

Due reminder → load its event → `notify_user` with type `event_reminder`,
title = event title, `data: {"event_id": …}` (lands in the recipient's inbox
_and_ is dispatched like any other notification) → `MarkReminderSent(id,
notificationID)`. Any error path (event gone, enqueue failure) →
`MarkReminderFailed`.

## FCM client (`internal/infrastructure/push`)

- `Provider` interface: `Name()`, `Send(ctx, Message) (string, error)`.
  Messages carry `Token`, `Title`, `Body`, `Data (map[string]string)`.
- Errors are typed (`push.Error` with `Code`): `CodeInvalidToken`,
  `CodeUnavailable`, `CodeFail`; helpers `IsInvalidToken()`/`Retryable()`.
- `fcm`: parses the service-account JSON, signs an RS256 JWT (kid = private key
  id) with the already-present `golang-jwt/jwt/v5`, exchanges it at
  `FCM_TOKEN_URL` for an access token (cached ~45 min), then `POST
  {FCM_API_BASE}/projects/{project}/messages:send`. **No new go.mod deps.**
- `noop`: returns a synthetic message id (`"noop-message-id"`) — the default
  in dev/tests, so the dispatch path is exercised end-to-end without Firebase.
- Factory `New(name, cfg)` → `fcm` or `NoopProvider`.

Config: `PUSH_PROVIDER` (default `noop`), `FCM_SERVICE_ACCOUNT`
(required when `fcm`), `FCM_PROJECT_ID`, `FCM_API_BASE`, `FCM_TOKEN_URL`;
tuning `PUSH_POLL_INTERVAL` (2s), `PUSH_BATCH_SIZE` (50), `PUSH_MAX_ATTEMPTS`
(5), `PUSH_RETRY_BASE_DELAY` (30s). Unknown `PUSH_PROVIDER` fails fast.

## Deviations / open items

- **RSVP fan-out has no trigger today.** `Notifier.NotifyEventRSVPs` +
  `RsvpRepository.ListUserIDsByEvent` (cap 200) are wired through
  `application.go`, but nothing calls them yet: comments are flat (no
  `parent_id` in migration 00011) and `UpdateEvent` only edits drafts, so the
  "event updated → RSVP'd users" and "comment reply" pushes have no source
  event. Planned follow-up (phase 18+).
- iOS/APNs is out of scope (FCM tokens only; `platform` is recorded for later).
- Real end-to-end send is **BLOCKED on credentials**: no Firebase project is
  configured yet (`PUSH_PROVIDER=noop` in dev/tests).