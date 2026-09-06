# Phase 06 — Admin Stale-Role Recheck (WS7)

## Goal

Ensure a demoted admin loses administrative access immediately, not up to
`JWT_EXPIRY` later. Admin routes re-check the role in the database; non-admin
routes keep trusting the short-lived JWT claim (documented 15m window).

## Impacted files

- `backend/internal/api/middleware/auth.go` (`RequireAdmin`)
- `backend/internal/api/handlers/organizers_test.go`/new admin-role test
- `backend/README.md` or `docs/PROGRESS.md` (staleness-window documentation)

## Tasks

- [x] 1. `RequireAdmin(auth)`: parse the Bearer token for identity only → set
      `UserIDKey` in context → obtain the request tx from context (fail closed
      with 500/403 if absent) → set RLS context as the authenticated user with
      the `admin` role (`database.SetRLSContextTx(ctx, tx, userID, "admin")`) →
      fetch the user via `auth.GetUser(r.Context(), userID)` → require
      `user.Role == "admin"`, else 403. Never fall back to trusting the claim.
- [x] 2. Leave the non-admin `RequireAuth` path claiming-trusted (no per-request
      DB hit on every endpoint); document that the max staleness window is
      `JWT_EXPIRY` (default 15m).
- [x] 3. Tests (DB):
      - promoted admin token approves an application → 200;
      - after demotion in DB (`service`-role `UPDATE users SET role='user'`), the
        **same old token** on approve → 403 immediately;
      - a freshly minted post-demotion token → 403;
      - non-admin on a protected admin route → 403 (existing behavior preserved).
- [x] 4. Run the gate; update `docs/PROGRESS.md`; commit on `main`.

## Verification gate

build/vet PASS · `go test -race -p 1 ./...` PASS (DB-backed role-change tests;
report DB availability honestly).

## Definition of Done

- [x] Admin authorization is re-verified server-side on every admin request.
- [x] Demotion takes effect immediately (no wait for JWT expiry).
- [x] Staleness window for non-admin endpoints documented.