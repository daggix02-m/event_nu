# Phase 07 — Pagination for Public List Endpoints (WS8)

## Goal

Bound `GET /api/v1/events` and `GET /api/v1/venues` with page/limit pagination
(server-enforced maximum), stable ordering, and the spec's envelope shape.

## Impacted files

- `backend/internal/repository/event.go` (`ListVisible(limit,offset)` + `CountVisible`)
- `backend/internal/repository/venue.go` (`ListActive(limit,offset)` + `CountActive`)
- `backend/internal/service/event.go` (`ListEvents`/`ListVenues` signatures)
- `backend/internal/api/handlers/events.go` (parse page/limit, envelope response)
- `backend/internal/api/dto/event.go` (pagination DTO)
- `backend/internal/api/handlers/organizers_test.go` / new pagination tests

## Context

Per spec §4 the paginated shape is:

```json
{ "data": [], "pagination": { "page": 1, "limit": 20, "total": 100, "has_next": true } }
```

Existing tests read `data` as an array, so the envelope stays backward compatible
for them; the change from bare-array to envelope is a client-facing change and
must be documented.

## Tasks

- [ ] 1. `repository/event.go`: `ListVisible(ctx, limit, offset)` ordering
      `ORDER BY starts_at, id LIMIT $1 OFFSET $2`; `CountVisible(ctx)` matching the
      same RLS/visibility WHERE. Venue equivalent ordering `name, id`.
- [ ] 2. `service/event.go`: `ListEvents(ctx, page, limit) (items, total int, err)`
      and `ListVenues(...)` same; compute offset from page; fetch `limit+1` rows to
      derive `has_next` without a second query (or use the count — pick one and
      keep it consistent).
- [ ] 3. `handlers/events.go`: parse `page` (default 1, must be ≥1) and `limit`
      (default 20, must be in 1..100). **Invalid values → 400** (negative,
      non-numeric, zero, >100) — do not silently clamp.
- [ ] 4. Response: `{ "data": [...], "pagination": {page, limit, total, has_next} }`.
- [ ] 5. Document the shape change (README/PROGRESS).
- [ ] 6. Tests (DB): default page size; custom size; enforced max (limit>100,
      limit=0, negative, non-numeric → 400); stable ordering across pages
      (insert >page rows, walk pages, assert no dupes/gaps); `has_next` boundary;
      venue pagination.
- [ ] 7. Run the gate; update `docs/PROGRESS.md`; commit on `main`.

## Verification gate

build/vet PASS · `go test -race -p 1 ./...` PASS (DB-backed pagination suite;
report DB availability honestly).

## Definition of Done

- [ ] Both list endpoints bounded (hard max 100, default 20) with 400 on bad params.
- [ ] Ordering stable across pages; envelope shape documented.