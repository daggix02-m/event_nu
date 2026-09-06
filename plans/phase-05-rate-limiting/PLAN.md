# Phase 05 — Authentication Rate Limiting (WS2)

## Goal

Rate-limit security-sensitive auth endpoints with 429 responses, configurable
limits, concurrency safety, and expired-state cleanup. Deployment topology is
**single-instance API** → in-memory limiter (documented); no Redis unless the
topology changes.

## Impacted files

- `backend/internal/config/config.go` (+ rate-limit env vars + validation)
- `.env.example` / `backend/README.md` (config docs)
- `backend/internal/api/middleware/ratelimit.go` (new)
- `backend/internal/api/middleware/ratelimit_test.go` (new, unit)
- `backend/internal/api/routes/routes.go` (wire onto the 4 auth routes)
- `backend/internal/api/handlers/auth_integration_test.go` (burst → 429)

## Tasks

- [ ] 1. `config/config.go`: add + validate (limit>0, window>0) with sensible
      defaults, e.g.:
      `AUTH_LOGIN_RATE_LIMIT` (20) / `AUTH_LOGIN_RATE_WINDOW` (5m)
      `AUTH_REGISTER_RATE_LIMIT` (5) / `AUTH_REGISTER_RATE_WINDOW` (1h)
      `AUTH_REFRESH_RATE_LIMIT` (30) / `AUTH_REFRESH_RATE_WINDOW` (5m)
      `AUTH_VERIFY_RATE_LIMIT` (20) / `AUTH_VERIFY_RATE_WINDOW` (1h)
      Docstring: single-instance in-memory choice is intentional.
- [ ] 2. `.env.example` + README config table entries.
- [ ] 3. New `middleware/ratelimit.go`: fixed-window limiter via
      `sync.Mutex` + `map[string]*bucket`; bucket = {windowStart, count};
      `Allow(key, limit, window) (ok bool, retryAfter time.Duration)`;
      concurrency-safe; janitor goroutine prunes expired buckets and a stop func
      is provided.
- [ ] 4. `ClientIP(r)` helper (X-Forwarded-For first value → else RemoteAddr),
      consistent with the existing `clientMeta` behavior.
- [ ] 5. Wire middleware onto login/register/refresh/verify routes: **IP bucket**
      on all four, **account bucket** (email from body, lowercased) additionally
      for login and register. Generic 429 body (no account-existence leak);
      `Retry-After` header set. Limiter state shared across requests via the
      `Application`/config.
- [ ] 6. Unit tests: window boundary (limit→block at exactly limit+1), window
      rollover resets count, concurrent `Allow` calls are safe, janitor prunes
      expired buckets, Retry-After math.
- [ ] 7. Handler integration tests: burst login attempts → last request 429 +
      Retry-After present; burst verify (with a fresh limiter state per test) →
      429; rate-limited response body is generic.
- [ ] 8. Run the gate; update `docs/PROGRESS.md`; commit on `main`.

## Verification gate

build/vet PASS · `go test -race -p 1 ./...` PASS (limiter unit tests DB-free;
burst integration tests report DB availability honestly).

## Definition of Done

- [ ] All four auth routes rate-limited by IP (login/register additionally by email).
- [ ] 429 + Retry-After; response reveals nothing about account existence.
- [ ] Limiter is concurrency-safe, cleans up expired state, and is env-configurable.
- [ ] In-memory/single-instance decision documented in code + report.