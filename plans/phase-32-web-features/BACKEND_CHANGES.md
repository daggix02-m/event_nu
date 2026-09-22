# Backend Changes: Announcements + Featured Flag (Web Parity)

**Status:** PLANNED ONLY — this document is the full, implementable design. Per
the Flutter-phase constraint, no code in `backend/` was changed to produce it.
Implementation happens in a dedicated backend session.

Two backend features are needed to reach full parity with the web product:

1. **Announcements** — a globally-visible, time-boxed message served to apps
   and the web (e.g. maintenance notices, editorial call-outs). Entirely new:
   the `announcements` table from target schema v3 (§8.26) does not exist in
   any shipped migration.
2. **Featured flag** — editorial "featured results" on events. The schema already
   shipped the `featured` column and `featured_section` enum (migration `00007`)
   but **nothing reads, writes, or exposes it** — it is a dead column today.

Everything below follows the codebase's established patterns: forward goose
migrations only, RLS-first with `is_privileged()` escalation, `shared.WriteJSON`
`{"data": ...}` envelopes, `validator`-based request validation, the
`public/optional/protected/admin` route helpers, and events already carrying
soft-delete semantics in the `/api/v1/sync` domain whitelist.

---

## 1. Announcements

### 1.1 Migration — `backend/migrations/00023_web_features.sql`

Match target schema v3 `announcements` exactly (no new columns).

```sql
-- +goose Up
CREATE TABLE announcements (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message    text NOT NULL,
  is_active  boolean NOT NULL DEFAULT true,
  starts_at  timestamptz,
  ends_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Readers only ever want currently-announced rows. The window filters are
-- applied in the service layer; this index keeps the active lookup cheap.
CREATE INDEX announcements_active_idx ON announcements (is_active, starts_at)
  WHERE is_active;

-- ---- RLS: announcements (mirrors target schema v3 exactly) ---------------
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON announcements TO app_user;
GRANT SELECT, INSERT, UPDATE ON announcements TO admin_dashboard;

CREATE POLICY announcements_select_public ON announcements FOR SELECT
  USING (is_active OR is_privileged());
CREATE POLICY announcements_write ON announcements FOR INSERT
  WITH CHECK (is_privileged());
CREATE POLICY announcements_update ON announcements FOR UPDATE
  USING (is_privileged()) WITH CHECK (is_privileged());

-- +goose Down
DROP TABLE IF EXISTS announcements;
```

Notes:

- The target schema defines **no DELETE policy** — rows are switched off with
  `is_active = false`, never removed. Follow that: an audit trail is preserved
  and the `announcements_select_public` policy stays simple.
- `app_user` gets `SELECT` only; `admin_dashboard` gets `SELECT, INSERT, UPDATE`.
  The Go admin endpoints in §1.7 (if adopted) still transit through `app_user`
  with `SET LOCAL app.role = 'admin'` via `middleware.WithRole("admin")` +
  `SetRLS`, so `is_privileged()` evaluates true and the write policies permit
  them.
- `created_at`/`updated_at` maintenance is the same convention as elsewhere:
  set `updated_at = now()` on UPDATE in the repository statement.

### 1.2 Domain + repository

```go
// backend/internal/domain/announcement.go
type Announcement struct {
    ID        string
    Message   string
    IsActive  bool
    StartsAt  *time.Time
    EndsAt    *time.Time
    CreatedAt time.Time
    UpdatedAt time.Time
}
```

`backend/internal/repository/announcement.go` — `AnnouncementRepository`:

| Method | SQL shape |
|---|---|
| `ListActive(ctx)` | `SELECT … FROM announcements WHERE is_active AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at > now()) ORDER BY starts_at NULLS LAST, created_at DESC` |
| `ListAll(ctx)` | `ORDER BY created_at DESC` (admin/editorial review) |
| `Create(ctx, a *Announcement)` | `INSERT … RETURNING …` |
| `Update(ctx, a *Announcement)` | `UPDATE announcements SET message=$2, is_active=$3, starts_at=$4, ends_at=$5, updated_at=now() WHERE id=$1 RETURNING …` |
| `Get(ctx, id)` | `SELECT … WHERE id=$1` |

Do **not** add a `Delete`. Inactive rows stay.

### 1.3 Service — `backend/internal/service/announcement.go`

- `ListActive(ctx) ([]*domain.Announcement, error)` — thin pass-through to
  `ListActive`; the DB window filter is the single source of truth.
- `Set(ctx, a)` / `Patch` — validate (`§1.5`), then persist. If the editor's
  new window is fully in the past, still persist; `is_active=false` is the
  user-facing "off" switch and the window is a scheduling aid.

### 1.4 DTO

```go
// backend/internal/api/dto/announcement.go
type AnnouncementDTO struct {
    ID        string     `json:"id"`
    Message   string     `json:"message"`
    IsActive  bool       `json:"is_active"`
    StartsAt  *time.Time `json:"starts_at"`
    EndsAt    *time.Time `json:"ends_at"`
    CreatedAt time.Time  `json:"created_at"`
    UpdatedAt time.Time  `json:"updated_at"`
}
```

The public read endpoint (`§1.6`) only ever returns rows where
`is_active == true` (RLS already hides inactive rows from `app_user`), but the
DTO still carries `is_active` so the admin view and the public view share one
shape.

### 1.5 Validation

Use the existing `validator` conventions (mirror `saveFolderMaxName = 100`):

| Field | Rule |
|---|---|
| `message` | required; trimmed non-empty; `MaxChars(2000)` |
| `is_active` | optional, defaults `true` |
| `starts_at` / `ends_at` | optional; if both set, `ends_at > starts_at` (reject otherwise with 422) |
| `id` | optional in create; required in update |

### 1.6 Public route

```go
mux.Handle("GET /api/v1/announcements", public(announcements.ListActivePublic))
```

Response (envelope, per `shared.WriteJSON`):
`{"data": [ <AnnouncementDTO>, … ]}`.

- `public()` — no auth; anyone (web, mobile, curl) can read currently-announced
  messages.
- Set a short `Cache-Control: public, max-age=300` on this handler; announcements
  are global and low-churn, so a 5-minute TTL is safe and cheap.

### 1.7 Authoring surface

Per target schema v3 the **admin dashboard** (Next.js/Prisma app, connecting as
`admin_dashboard`) owns `INSERT`/`UPDATE` — that is the primary authoring path
and requires **no Go work**. Two options, in preference order:

- **(a) Dashboard-only (recommended).** Announcements parity is purely additive
  on the Go side: the public read endpoint. Authoring stays in the Prisma admin
  app where the other CMS concerns already live.
- **(b) Optional Go admin endpoints** for environments that want Go-side
  editing: `POST /api/v1/admin/announcements` and
  `PATCH /api/v1/admin/announcements/{id}` behind the existing `admin()`
  helper (`RequireAdmin` + `WithRole("admin")` + `SetRLS`). Idempotency: `POST`
  behind `protectedIdem` like other creates. Choose (a) unless the web team
  needs Go-side editing.

### 1.8 Sync notes

Do **not** add `announcements` as a sync domain.

- The `/api/v1/sync` delta finder (`sync_deleted_ids`) only supports
  soft-delete tables, and `announcements` has no `deleted_at`. Adding it would
  require a second mechanism for hard-delete tears, which the schema
  deliberately avoids.
- Announcements are global and small. The flat `GET /api/v1/announcements`
  (optionally with the short cache header) is a better fit than per-user cursor
  deltas.
- Syncing clients (mobile offline cache) can coalesce `announcements` into a
  "refresh global banners" poke: fetch on app foreground / daily interval, not
  per cursor tick.

---

## 2. Featured flag

### 2.0 Current state (verified in `backend/`)

- Migration `00007` ships the enum and column:
  `CREATE TYPE featured_section AS ENUM ('editors_choice','trending','new_and_noteworthy');`
  and `featured featured_section` on `events`.
- **Nothing reads it.** `eventColumns`/`eventColumnsQualified` in
  `repository/event.go` do not select `featured`; `domain.Event`, `toEventDTO`,
  `EventDTO`, `AdminEventDTO` do not carry it; no endpoint writes it and no
  discovery filter references it.

So the DB layer is done; the gap is entirely API/domain exposure.

### 2.1 Migration

No migration is required to make the flag operational — the column exists on
the live schema. One optional index makes the editorial rails cheap (put it in
`00023_web_features.sql` from `§1.1` if that file is otherwise created):

```sql
CREATE INDEX events_featured_idx ON events (featured)
  WHERE deleted_at IS NULL;
```

### 2.2 Domain + repository

Add to `domain.Event`:

```go
Featured *string `json:"featured"` // "" / "editors_choice" | "trending" | "new_and_noteworthy"
```

`repository/event.go` changes:

- Add `featured` to both `eventColumns` constant blocks (and to the
  `pgx` `Scan` call in `scanEvent`, aligned positionally with the table
  column order).
- New method:
  `SetFeatured(ctx, eventID string, section *string) error` →
  `UPDATE events SET featured = $2, updated_at = now() WHERE id = $1`
  (a `NULL` clears the flag). Keep it idempotent — re-setting the same section
  is a no-op row-level update.
- Extend `ListVisible` + `CountVisible` + `eventSearchClause` with a featured
  filter (`§2.4`), or add a dedicated `ListFeatured` query. Prefer extending
  `eventSearchClause` so editorial rails compose with `q`/`category`/date/geo
  filters without a second code path.

### 2.3 Admin write endpoint

```go
// 422 for an unknown section; setting null clears the flag.
mux.Handle("PATCH /api/v1/admin/events/{id}/featured", admin(adminHandlers.SetEventFeatured))
```

Request:
`{"section": "editors_choice" | "trending" | "new_and_noteworthy" | null}`

Response: `{"data": { … updated EventDTO … }}` (or a minimal `{"featured": …}`).

Service rules:

1. `RequireAdmin` + `WithRole("admin")` + `SetRLS` — same `admin()` helper used
   by the moderation endpoints. RLS `events_update_own` already permits
   `is_privileged()` writes.
2. Fetch the event; if absent → 404.
3. Only **published**, non-blocked, non-deleted events may be featured
   (editorial surface). Return 422 `EVENT_NOT_FEATUREABLE` otherwise. This is a
   service-layer guard, not a DB constraint, so a later reversal is easy.
4. Section must be one of the enum members (or absent/`null` to clear) — 422
   otherwise. Validate *before* touching the DB.
5. Clear-on-behalf invariants: if a `cancelled`/`completed`/`blocked` transition
   happens elsewhere, the moderation paths should also clear `featured` so
   stale editorial picks never surface (add one `UPDATE … SET featured = NULL`
   to `BlockEvent`).

### 2.4 Public read

Build editorial rails as a **filter on the existing discovery endpoint** rather
than a new collection route, so it shares pagination, geo/FTS, and envelope
behaviour:

```
GET /api/v1/events?featured=editors_choice
GET /api/v1/events?featured=trending
GET /api/v1/events?featured=new_and_noteworthy
```

`parseEventFilters` gains `f.Featured = q.Get("featured")`; `EventFilters`
gains `Featured string`; `eventSearchClause` adds
`AND (e.featured = $n)` when non-empty. `optional()` auth is enough — featured
lists are public, and the per-user like/save fields already degrade cleanly.

### 2.5 DTO exposure

Add to `EventDTO`, `AdminEventDTO`, and the lightweight summary DTO used by
search/sync feeds:

```go
Featured *string `json:"featured"`
```

`toEventDTO` sets it from `domain.Event.Featured`. The Flutter event summary
model ignores unknown JSON keys today, so mobile gains nothing until it opts in
— this is purely additive and backward compatible.

### 2.6 Sync notes

- `events` is already a sync domain: whole-row soft-delete semantics, listed in
  the `sync_deleted_ids` whitelist, emitted with full event payloads via
  `toSyncPayload` → `toEventDTO`.
- Once `eventColumns` includes `featured` and `toEventDTO` maps it, **featured
  rides the existing event delta for free** — no new domain, no migration, no
  client-side cursor work. Mobile offline caches will see it as a regular event
  column change.
- Admin-only flag mutations bump `updated_at`, which is what makes the change
  appear in subsequent pull deltas — the same contract the moderation path
  already relies on.

### 2.7 Tests

Mirror the existing fake-store pattern in `service/event_test.go`:

- `SetFeatured` happy path (set/clear), 404 unknown event, 422 non-published or
  unknown section, idempotence.
- `ListEvents` with `Featured` filter returns only matching visible events and
  composes with `q` + category.
- Repository test against Neon (like the existing DB-backed suite): set a real
  row's featured, assert `ListVisible` honours it and `featured` scans non-null.

---

## 3. File-by-file change summary

| Area | File | Change |
|---|---|---|
| Migration | `backend/migrations/00023_web_features.sql` | `announcements` table + RLS + `announcements_active_idx` (new) |
| Migration | same file | optional `events_featured_idx` (new) |
| Domain | `backend/internal/domain/announcement.go` | `Announcement` (new) |
| Domain | `backend/internal/domain/event.go` | `Featured *string` (new field) |
| Repository | `backend/internal/repository/announcement.go` | `AnnouncementRepository` (new) |
| Repository | `backend/internal/repository/event.go` | select/scan `featured`; `SetFeatured`; featured clause in `eventSearchClause` |
| Service | `backend/internal/service/announcement.go` | `ListActive`, authoring service (new) |
| Service | `backend/internal/service/admin.go` | `SetEventFeatured` + featured-clear on block |
| DTO | `backend/internal/api/dto/announcement.go` | `AnnouncementDTO` (new) |
| DTO | `backend/internal/api/dto/event.go` | `Featured` on `EventDTO`/`AdminEventDTO` (+ summary DTO) |
| Handler | `backend/internal/api/handlers/admin.go` | `SetEventFeatured` |
| Handler | `backend/internal/api/handlers/events.go` | `parseEventFilters` → `featured`; `toEventDTO` → `featured` |
| Handler | `backend/internal/api/handlers/announcements.go` | `ListActivePublic`, admin write handlers if (b) chosen (new) |
| Routes | `backend/internal/api/routes/routes.go` | `GET /api/v1/announcements`, `PATCH /api/v1/admin/events/{id}/featured` (+ admin announcements if (b)) |
| Config | `backend/internal/api/application.go` | wire `AnnouncementService` + `AnnouncementRepository` |

## 4. Rollout order

1. Migration `00023` (announcements + featured index) via goose.
2. Domain/repo/service/DTO for announcements + public route — ship read-only.
3. `featured` plumbing (scan, DTO, filter).
4. Admin `PATCH /events/{id}/featured` + block-clear.
5. Full gate: `gofmt` CLEAN · `go build ./...` PASS · `go vet ./...` PASS ·
   `go test -race -p 1 -count=1 ./...` PASS · `go mod tidy -diff` clean.

No backend change in this document is required for any *already-shipped*
migration; `00023` is strictly forward.