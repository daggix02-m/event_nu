# Phase 09 — Input Validation + Lean Observability (WS10 + WS13)

## Goal

- Turn invalid UUID path params from Postgres `22P02` 500s into clean 404s.
- Add minimal health-harvestable `/metrics` counters without pulling in a metrics
  dependency (lean stdlib) or touching `LogRequest`'s fresh redaction.

## Impacted files

- `backend/internal/api/handlers/organizers.go` (`GetOrganizer` et al.)
- `backend/internal/api/handlers/events.go` / any handler receiving UUID path params
- `backend/internal/api/handlers/health.go` (`/metrics` handler)
- `backend/internal/api/routes/routes.go` (register `/metrics`)
- new `internal/api/metrics/metrics.go` (runtime/stats counters)
- new tests: invalid-UUID → 404; metrics path returns 200 text

## Tasks

- [x] 1. Add a shared `ParseUUIDParam(r, "id") (uuid.UUID, bool)` helper that
      returns false for malformed values. Every handler that binds a UUID path
      param: if !ok → `404` (with the standard not-found body/first placeholder),
      **before** any DB call. Re-check all current UUID path handlers for the
      `22P02` → 500 path (organizer by id, event by id, venue by id, etc.).
- [x] 2. Confirm with an integration test that
      `GET /api/v1/organizers/not-a-uuid` (and one event/venue equivalent) returns
      404, not 500; keep sub-detail generic (404 without hinting).
- [x] 3. New `metrics.go` (no external dependency): prometheus-text-format
      endpoint with process memory (`runtime.ReadMemStats`), goroutines, GC count,
      and `http_requests_total` counter incremented by a small middleware added
      alongside the auth stack (not inside `LogRequest`).
- [x] 4. Register `GET /healthz/metrics` (or `/metrics` per repo convention) on a
      non-RLS, no-auth route; `/metrics` handler does **not** read the tx context.
- [x] 5. Tests: metrics endpoint 200 + expected labels; invalid-UUID matrix (DB-free).
- [x] 6. Run the gate; update `docs/PROGRESS.md`; commit on `main`.

## Verification gate

`gofmt -l` clean · build/vet PASS · `go test -race -p 1 ./...` PASS (invalid-UUID
matrix DB-free; event/venue 404 check reports DB availability honestly).

## Definition of Done

- [x] Malformed UUIDs return 404 everywhere; no `22P02` 500 reaches clients.
- [ ] `/metrics` exposes process + request counters with no new dependencies.