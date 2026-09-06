# Phase 03 — Atomic Refresh Token Rotation (WS1)

## Goal

Make refresh-token consumption atomic so one token can be consumed by at most
one concurrent request. The whole rotation (consume → validate → issue
replacement) must commit or roll back as one unit.

## Impacted files

- `backend/internal/repository/session.go` (`ConsumeForRotation`)
- `backend/internal/service/auth.go` (`Refresh`)
- `backend/internal/repository/session_test.go` (new concurrent repo test)
- `backend/internal/api/handlers/auth_integration_test.go` (new concurrent handler test)

## Tasks

- [ ] 1. `repository/session.go`: add
      `ConsumeForRotation(ctx, refreshHash) (*domain.Session, error)` — a single
      statement:
      ```sql
      UPDATE auth_sessions
      SET revoked_at = now(), updated_at = now()
      WHERE refresh_hash = $1 AND revoked_at IS NULL AND expires_at > now()
      RETURNING id, user_id, refresh_hash, user_agent, ip_hash, device_name, expires_at, revoked_at, created_at, updated_at
      ```
      Zero rows → `shared.ErrNotFound`. Runs through the request-tx querier
      (`r.q(ctx)`) like every other repo method.
- [ ] 2. `service/auth.go` `Refresh`: call `ConsumeForRotation` first (it both
      reads and revokes atomically), then `users.GetByID`, then `newSession` —
      all inside the per-request tx (`BeginRequestTx`). If any later step fails,
      the tx rolls back and the revocation is undone (token stays usable).
      Non-`ErrNotFound` DB errors still propagate; `invalid_refresh_token` 401 on
      not-found (consumed/expired/revoked all land here).
- [ ] 3. Repo test (DB): `Begin` two tx from the pool, both call
      `ConsumeForRotation` on the same active hash concurrently → exactly one
      returns the session; the other → `ErrNotFound`; the row is revoked in the DB.
- [ ] 4. Handler integration test: register → run N (≥8) goroutines hitting
      `POST /api/v1/auth/refresh` with the same token → exactly one 200, N-1 x
      401; retrying the winning token afterwards → 401.
- [ ] 5. Confirm no plaintext refresh token is stored or returned outside the
      response (hash-only at rest).
- [ ] 6. Run the gate; update `docs/PROGRESS.md`; commit on `main`.

## Verification gate

build/vet PASS · `go test -race -p 1 ./...` PASS (concurrent tests exercised;
report DB availability honestly).

## Definition of Done

- [ ] Refresh consumption is a single atomic UPDATE (no read-then-revoke window).
- [ ] Concurrent refresh of one token → exactly one success.
- [ ] Expired/revoked/replayed tokens all rejected with the existing 401 contract.