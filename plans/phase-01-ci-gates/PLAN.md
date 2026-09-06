# Phase 01 — CI Quality Gates (WS12)

## Goal

Add CI that enforces the same gates as local development (fmt/vet/build/test),
with a Postgres service so integration/RLS tests actually run against a
database — including the migrations required to provision `app_user`.

## Impacted files

- `.github/workflows/ci.yml` (new)
- `backend/Makefile` (optional `ci` mirror target)
- `backend/README.md` (CI + local-Postgres instructions)
- `.env.example` (document the CI/Postgres-derived env vars)

## Context

- Migration `00007_organizers_and_events.sql` contains `GRANT … TO app_user`,
  so the role must exist before migrations run.
- RLS proof tests require a **non-superuser** connection (`DATABASE_URL` =
  `app_user`), because a superuser bypasses RLS and the cross-user-block tests
  would fail.
- Tests run `go test -race -p 1 ./...` because packages share one database.
- CI always runs `go test` against its own Postgres service; local Neon is only
  for ad-hoc dev runs.

## Tasks

- [ ] 1. Create `.github/workflows/ci.yml`:
      - triggers: `push` (main) + `pull_request`.
      - job runs `ubuntu-latest`; service `postgres:16` with a password + health check.
      - checkout, `actions/setup-go` pinning the `go.mod` version, Go build cache.
      - bootstrap step (as postgres superuser): `CREATE ROLE app_user LOGIN PASSWORD ...`,
        `GRANT` DB/schema/tables/sequences per the migration requirements.
      - run `goose` migrations (`cd backend/migrations && goose postgres "$DATABASE_ADMIN_URL" up`).
      - gates: `gofmt -l .`, `go vet ./...`, `go build ./...`,
        `go test -race -p 1 ./...` with `DATABASE_URL` pointed at the service DB.
- [ ] 2. Add a `ci` target to `Makefile` mirroring the gate so local runs match CI.
- [ ] 3. Document in `backend/README.md`: how CI provisions the DB, why
      `app_user` (non-superuser) is required, and how to run the same gates locally.
- [ ] 4. Validate the YAML (parse check). Note: the live CI run happens on the
      first push — mark **BLOCKED** locally if no push is made this session.
- [ ] 5. Update `docs/PROGRESS.md` with the CI outcome.
- [ ] 6. Commit on `main` (e.g. `ci: add quality gates with Postgres service + app_user bootstrap`).

## Verification gate

YAML parses · gate commands are provably the CI steps · local `make ci`
equivalent runs the full suite (DB-backed tests BLOCKED without a local Postgres —
report honestly).

## Definition of Done

- [ ] CI enforces fmt, vet, build, test with a Postgres service.
- [ ] Migrations run in CI; `app_user` bootstrapped before migrations.
- [ ] README documents CI + local equivalent.