# Sync Protocol — `GET /api/v1/sync` (Phase 16)

The offline delta endpoint lets the Flutter app rebuild or advance its local
cache: one authenticated call returns everything that changed in the public
catalog since a cursor, plus a cursor to poll with next. It is the single
source of truth the app drives its SQLite stores from.

- **Locked**: Phase 16 (2026-09-11). Cursor = `updated_at` delta, soft-delete
  only. Scope = public-discovery domains delta + private domains refreshed
  wholesale (per-user rows stay out of sync by design).
- **Auth**: Bearer token required (`protected` middleware; RLS scopes every row
  to the caller). GET is idempotent — `Idempotency-Key` is not needed.
- **Spec source**: `EVENT_NU_IMPLEMENTATION_DOCUMENTATION_v3.md` §13.2/§13.3.

## Request

```
GET /api/v1/sync?cursor=<RFC3339>&domains=<d1,d2,...>&limit=<n>
```

| Param | Default | Meaning |
|---|---|---|
| `cursor` | epoch (full bootstrap) | Inclusive: rows with `updated_at >= cursor`. `time.RFC3339` (fractional seconds allowed; response uses `RFC3339Nano`). |
| `domains` | all whitelisted domains | comma-separated; unknown domain → 400 `bad_request`. |
| `limit` | `SYNC_MAX_LIMIT` (500) | max changes **per domain per page**; 1…`SYNC_MAX_LIMIT`. |

`SYNC_MAX_LIMIT` is validated in `config.Load` (default `"500"`, must be 1…1000).

## Response

```json
{
  "data": {
    "changes": [
      { "domain": "events",  "op": "upsert", "id": "<uuid>", "payload": { } },
      { "domain": "reviews", "op": "delete", "id": "<uuid>", "payload": null }
    ],
    "next_cursor": "2026-09-11T09:01:11.576014Z",
    "has_more": { "events": true }     // key present ONLY while a domain still has pages
  }
}
```

- `op: "upsert"` → upsert the row locally (idempotent — same `id` may appear in
  later pages as the boundary row; upsert overwrites).
- `op: "delete"` → drop the local copy of `id`. `payload` is always `null`.
- `changes` is emitted in domain order (`events, venues, organizers,
  categories, ticket_types, comments, reviews`), rows within a domain in
  `(updated_at, id)` order — the client can apply them in order.
- `has_more`: present only when at least one requested domain still has rows
  beyond the current page. Missing → every requested domain is exhausted.
- `next_cursor` is **always present**. Polling with it exactly reproduces the
  boundary rows (the cursor is inclusive), so consumers must upsert
  idempotently. This is what guarantees forward progress across rows that share
  an `updated_at` timestamp.

## Domains

| Domain | Upsert filter (RLS + explicit) | Delete ops |
|---|---|---|
| `events` | published, not blocked, not deleted | yes (soft) |
| `venues` | active, not deleted | yes (soft) |
| `organizers` | active, not deleted | yes (soft) |
| `categories` | `is_active` | no |
| `ticket_types` | `is_active` | no |
| `comments` | not deleted, not blocked | **no** — comments are hard-deleted (`DELETE FROM comments`); a vanished comment is simply absent from future deltas |
| `reviews` | published, not deleted | yes (soft) |

**Delete ops are only produced for soft-deleting tables.** The hard-delete case
(comments) is intentionally excluded from the delete whitelist both in Go
(`service.SyncDeleteCapable`) and in SQL (`sync_deleted_ids`).

### Why soft deletes need a privileged helper

RLS filters soft-deleted rows out of `app_user` SELECTs (`deleted_at IS NULL`
in every public policy), so a normal delta scan can never *observe* a deletion.
`sync_deleted_ids(p_since, p_domain, p_limit)` is a `SECURITY DEFINER` function
(owner = migration runner, `SET search_path = public`) that returns only
`{row_id, changed_at}` — never row content — so callers learn a row vanished
without learning what it said. The domain whitelist is enforced inside the
function and the table name only reaches `format('%I')` after the whitelist
check, so it is not injectable. Granted to `app_user`.

## Cursor & pagination algorithm

- The request transaction is READ COMMITTED (RLS context set via
  `set_config`), so a poll sees a serviceable point-in-time snapshot of every
  domain.
- Per domain, the repository reads `limit+1` rows and reports whether the
  extra (sentinel) row existed → `has_more`, without a count query.
- Per-domain **watermark** = max `updated_at` (upserts) or `changed_at`
  (deletes) over **every row read**, including the sentinel row. Using the full
  read horizon — not just the emitted page — is what lets the inclusive cursor
  re-emit a boundary row without ever stalling pagination.
- **`next_cursor`**:
  - any domain still has rows → the smallest watermark among unfinished
    domains (`clamp`), so the next poll resumes without gaps;
  - otherwise → the maximum watermark across all requested domains
    (`advance`). Numeric/string-wise and time-wise it is monotonically
    non-decreasing in every subsequent poll.
- Because the cursor is inclusive, a page boundary row can legitimately appear
  in two consecutive responses. Clients upsert idempotently and never count on
  a row appearing exactly once.

## Race window (documented, accepted)

A row that is hard-deleted or mutated+deleted in the window between a user's
poll and their next poll may be missed (the soft-delete helper also cannot see
rows deleted before the read snapshot). The client treats sync as eventually
consistent: on targeted reads (event detail, organizer profile) it falls back
to the plain API endpoints, which correct any missed rows. No server-side
reconciliation jobs are planned.

## DTO downsizing (deliberate)

Sync payloads intentionally carry **no per-user decorations or media URLs**,
so the delta stays small and free of N+1 lookups:

- events: plain `toEventDTO` — `like_count`/`liked_by_me`/`saved_by_me`/
  `saved_folder_id` zeroed, `poster_url`/`teaser_url` empty;
- organizers: `OrganizerDTO` without follower counts / `followed_by_me`;
- ticket types: availability (`sold_out`, `sales_open`) computed with the
  server clock at response time;
- venues / categories / comments / reviews: the same shapes their plain
  endpoints return.

The app re-fetches personalization via the private endpoints on reconnect
(the "private full refresh" half of the sync contract).

## Tests

- `internal/repository/sync_test.go` — RLS-scoped delta scan, privileged
  delete-id visibility vs. upsert invisibility, `limit`-capped `has_more`,
  whitelist rejection of hard-delete domains.
- `internal/api/handlers/sync_integration_test.go` — auth required (401),
  param validation (400s), delta upserts after a fresh cursor, monotonic
  cursors, `limit=1` pagination terminates and converges on every event, and a
  review soft-delete surfaces as a `delete` op with a null payload.

## Files

- `backend/migrations/00018_sync.sql` — `sync_deleted_ids` + sync indexes.
- `backend/internal/repository/sync.go`, `internal/service/sync.go`,
  `internal/api/handlers/sync.go`, `internal/api/dto/sync.go`.
- `SYNC_MAX_LIMIT` handled in `backend/internal/config/config.go`.