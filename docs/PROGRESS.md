# Event Nu — Progress Tracker

**Living status file.** Update after every step/slice. Track status from start through testing and production.
**Date initialized:** 2026-09-01
**Source of truth:** `EVENT_NU_IMPLEMENTATION_DOCUMENTATION_v3.md` (spec) + `IMPLEMENTATION_PLAN.md` (plan).

---

## 0. Legend

Every verification gate is reported with **evidence**:

- **PASS** — command actually ran and completed successfully.
- **FAIL** — command ran and failed; the error and fix are recorded below.
- **BLOCKED** — could not run because a dependency/environment piece was unavailable; state exactly what's missing.
- **NOT RUN** — intentionally not attempted; say why.

Never claim something passes without having run it.

---

## 1. Milestone 1 — "Boot, auth, Brevo email"

| Step | Description | Status | Evidence / Gate |
|---|---|---|---|
| 1 | Repo bootstrap (git init, remote, layout, Makefile, first commit) | **done** | git init'd, remote set, backend/ scaffolded, module + deps, Makefile; build PASS |
| 2 | Foundation boots (config, application, middleware, server, healthz/readyz) | **done** | build/vet PASS; `/healthz` 200, `/readyz` 200 against Neon; request_id populated in logs |
| 3 | DB + migrations (00001_core, 00002_auth) | **done** | goose applied both migrations to Neon (version 2); `/readyz` green |
| 4 | Auth vertical slice (register/login/refresh/logout, /me) | **done** | live smoke: register→login→/me 200, no-token 401; full auth matrix test PASS with `-race` |
| 5 | Brevo email (outbox, worker, welcome + verify) | **done** (noop) | live E2E: register→outbox→worker→verify→is_verified; replay rejected; worker retry/dead-letter tests PASS. Real Brevo send **BLOCKED** (SMTP relay not activated → 403) |
| 6 | RLS context (SET LOCAL, app_user role) | **done** | migrations 00004–00006; app_user role created; DATABASE_URL switched to app_user; per-request tx + RLS context (service/user roles); cross-user read blocked (RLS proof tests PASS); live smoke as app_user PASS |
| 7 | First product slice (organizer applications → venues → categories → events → discovery) | **done** | migrations 00007–00009; apply→approve→organizer→venue→event→publish→public discovery; authz matrix test PASS (non-admin 403, cross-organizer 403, draft hidden, published visible) |
| 8 | Post-slice hardening: Brevo config fail-fast + backend README | **done** | commit `6801c2f` (2026-09-02); full gate `build`/`vet`/`go test -race -p 1 -count=1 ./...` PASS; fresh API boot smoke healthz/readyz 200 vs Neon |
| 9 | **Hardening plan scaffold + baseline (phase-00)** | **done** | `plans/` (README index + `phase-00…phase-11/PLAN.md`) at repo root; Go version consistency verified (toolchain `go1.26.6` ↔ `go.mod go 1.26.6`); `gofmt -w .` normalized 50 files (EOF trailing newline only, no semantic change); baseline gate: fmt CLEAN, build PASS, vet PASS, `go test -race -p 1 -count=1 ./...` PASS (handlers 122s, repository 20s, service 23s, worker 29s; DB-backed tests ran against Neon), golangci-lint **BLOCKED** (not installed) |

**First milestone (definition of done):**
register → login → profile → organizer application → admin approval → create event → publish → discovery → event details → real venue → navigation.

---

## 2. Phase Tracker (spec §23 / plan §4)

Current phase: **phase 15 (Chapa payments + webhooks) shipped 2026-09-11** — migration 00017 (DB v17), provider abstraction (Chapa `/transaction/initialize` + `/verify` + HMAC `Chapa-Signature`/`x-chapa-signature` over the raw body), card-init wired into order create (init failure rolls the whole request back — no orphan order, no inventory leak), privileged `POST /webhooks/payments/chapa` driving `ConfirmPaid`/`FailPayment`, payments ledger (RLS + SECURITY DEFINER `record_pending_payment` + currency trigger), `payment_provider`/`provider_ref` on order DTOs, noop provider for dev/tests. See row below + `docs/chapa.md`. Outside API completion, Phase C end-to-end Brevo send remains blocked on the 403 relay gate. Next: Phase 16 (offline sync) / Phase 17 (notifications push).

| Phase | Area | Status |
|---|---|---|
| 0 | Product/architecture contract | **done** (spec v3) |
| 1 | Repository foundation | **done** (2026-09-01) |
| 2 | Neon DB foundation | **done** — migrations 00001–00003 applied |
| 3 | Go API foundation | **done** — healthz/readyz, middleware, server |
| 4 | Authentication | **done** — register/login/refresh/logout + /me; email welcome+verify (outbox+worker) |
| 5 | RLS context | **done** — base framework + policies on users/auth_sessions/magic_link_tokens/email_*; cross-user reads blocked (proven) |
| 6 | Flutter offline foundation | not started |
| 7 | Users and profiles | **done** (auth slice covers /me) |
| 8 | Organizer applications | **done** — apply + admin approve/reject |
| 9 | Venues and categories | **done** — venue create/list, categories seeded |
| 10 | Events/posts + lifecycle | **done** — create/edit/publish, draft→published visibility |
| 11 | Media (R2) | not started |
| 12 | Discovery/search | not started |
| 13 | Social | not started |
| 14 | RSVP | not started |
| 15 | Tickets + orders + payments | **partial** — tickets & orders done (phase 14, 2026-09-10); Chapa payments/webhooks pending (phase 15) |
| 16 | Reviews/ratings | not started |
| 17 | Reporting + moderation | not started |
| 18 | Notifications + reminders | not started |
| 19 | Next.js admin | not started |
| 20 | Prisma + admin RLS | not started |
| 21 | Full offline sync | not started |
| 22 | Production hardening | not started |
| 23 | Testing (all layers) | partial — auth matrix + middleware + service done |
| 24 | Production deployment | not started |
| 24a | Config fail-fast + backend README | **done** — `6801c2f` (2026-09-02) |
| 25–29 | Hardening / observability / deploy / verify | **done** — security hardening `plans/phase-00…11` completed on `main` (all phases shipped: baseline, CI gates, auth quick wins, refresh atomicity, approval atomicity, rate limiting, admin recheck, pagination, idempotency, validation+metrics, worker reliability, final audit; see Testing Log rows 25–29). Next per plan: deploy + verify. |

---

## 3. Per-Slice Definition of Done Checklist (spec §27)

Check off for **every** slice as it lands:

- [ ] **Database:** migration
- [ ] **Database:** constraints
- [ ] **Database:** indexes
- [ ] **Database:** RLS
- [ ] **Backend:** entity
- [ ] **Backend:** repository
- [ ] **Backend:** service
- [ ] **Backend:** handler
- [ ] **Backend:** validation
- [ ] **Backend:** authorization
- [ ] **Backend:** errors (wrapped, centralized)
- [ ] **Backend:** idempotency (where needed)
- [ ] **Flutter:** local model / offline / sync / UI / error handling *(when applicable)*
- [ ] **Admin:** dashboard / Prisma / Go action / RLS / audit *(when applicable)*
- [ ] **Testing:** unit
- [ ] **Testing:** integration
- [ ] **Testing:** authorization
- [ ] **Testing:** offline *(when applicable)*
- [ ] **Operations:** logging
- [ ] **Operations:** monitoring
- [ ] **Operations:** failure recovery

---

## 4. Testing Log (spec Phase 23)

Record the actual command outcome for each layer as it runs.

| Layer | Status | Command / Evidence |
|---|---|---|
| Unit | **done** | service (JWT round-trip, hash, validation), shared JSON helpers, config fail-fast incl. Brevo template-ID guard (`6801c2f`) |
| Integration | **done** | full auth flow matrix vs real Neon DB (register/login/refresh-rotation/logout/me) |
| Repository | **done** (auth) | exercised via integration tests; NULL-safe user scan, constraint-aware errors |
| HTTP handler | **done** (auth) | httptest matrix incl. malformed input, boundary values, authz |
| Authorization / RLS | **done** | cross-user read/session blocked under RLS (proof tests PASS) |
| Offline sync | not started | — |
| End-to-end | **done** (auth) | live smoke via running server |
| Load / performance | not started | — |
| Payment / webhook | not started | — |
| Worker / job recovery | **done** (email) | fake Brevo server tests: send, retry-then-success, dead-letter; drain via noop worker |
| 8 unused packages | **done** (2026-09-06) | added test files to every `[no test files]` package: `cmd/api`+`cmd/worker` (newLogger dev/prod format+level, stdout capture), `api` (NewApp wiring/isolation), `api/dto` (JSON field-name + round-trip contract), `api/routes` (healthz/readyz/404/405/401 + route-registration matrix, DB-backed), `domain` (role constants, zero-value/optional-pointer guards), `infrastructure/email` (Brevo payload+headers, 200/201/4xx/5xx error mapping, Retryable matrix, baseURL trim, Noop), `validator` (email/required/min/max runes/order). Gate: fmt CLEAN · vet PASS · `go test -race -p 1 -count=1 ./...` all 16 packages `ok` |
| CI quality gates (**phase-01**, 2026-09-06) | **done** | `.github/workflows/ci.yml` (push main + PR): postgres:16 service + `app_user` bootstrap (CREATE ROLE, CONNECT/SCHEMA USAGE, `ALTER DEFAULT PRIVILEGES`→app_user) → goose `up` → gofmt/vet/build/tests; `make ci` mirror target; README + `.env.example` docs. **Validated end-to-end locally**: same bootstrap+migrations applied clean on a fresh `postgres:16` container (9/9 migrations up), `make ci` PASS (all 16 packages, DB-backed + RLS proof tests ran as `app_user`, not skipped), YAML parse OK. **Live CI run**: BLOCKED until first push (run happens on GitHub). golangci-lint: BLOCKED (not installed locally; still absent from the workflow — separate follow-up). Note: local shell exports `GOROOT=<mise go/1.26.4>` while the active `go` is the distro go1.26.6 → tool/compile mismatch; gate run with `env -u GOROOT` (project `go.mod` pins 1.26.6; setup-go in CI is unaffected) |
| Auth quick wins (**phase-02**, 2026-09-06) | **done** | login: `service/auth.go` now burns a real cost-12 dummy hash via a swappable `bcryptCompare` seam when the email is unknown, so not-found and wrong-password paths invoke bcrypt exactly once each (`TestLoginBcryptWorkOnUnknownEmailAndWrongPassword` proof-by-count) and return byte-identical `invalid_credentials`/401. Verify: `SendVerification` emits `verify_url = "eventnu://verify"` (constant, code-free) + separate `verify_code` param; `GET /api/v1/auth/verify` handler + route deleted → 405 (`TestDeprecatedVerifyGETReturns405`); outbox payload assertions in `email_integration_test.go`. Logs: `LogRequest` logs `r.URL.Path`, never the query string (`TestLogRequestRedactsQueryString` — `?code=SECRET&access_token=X` absent from output). Gate: gofmt clean · build/vet PASS · `go test -race -p 1 -count=1 ./...` all 16 packages `ok` (handlers 135s; `TestReadyzRoute` needed one transient rerun during the first gate pass — DB unreachable from Neon pool, green on rerun). Contract: login errors unchanged (invalid_credentials/401 both paths); verify is now POST-only |
| Refresh atomicity (**phase-03**, 2026-09-06) | **done** | `repository/session.go` adds `ConsumeForRotation(ctx, refreshHash)` — one atomic `UPDATE auth_sessions SET revoked_at=now()… WHERE refresh_hash=$1 AND revoked_at IS NULL AND expires_at>now() RETURNING …`; zero rows → `shared.ErrNotFound`. `service/auth.go` `Refresh` now consumes first, then `users.GetByID` + `newSession`, all in the per-request tx (`BeginRequestTx`): any later failure rolls back and revokes nothing (token stays usable); consumed/expired/revoked all keep the existing `invalid_refresh_token`/401 contract. Tests: `TestConsumeForRotationConcurrent` (repo, service-role, two tx on same hash → exactly 1 winner + 1 ErrNotFound, row revoked) and `TestRefreshConcurrentSingleWinner` (handler, 8 goroutines on same token → exactly one 200, 7×401, replay of the consumed token → 401). Hash-only at rest re-confirmed: DB stores sha256 `refresh_hash` only; `LogRequest` logs path only, body never. Gate: gofmt clean · build PASS · vet PASS · `go test -race -p 1 -count=1 ./...` all 16 packages `ok` (handlers 151s, repository 31s — DB-backed vs Neon) · golangci-lint **BLOCKED** (not installed) |
| Approval atomicity (**phase-04**, 2026-09-06) | **done** | `repository/organizer.go` replaces non-atomic read-then-update `ReviewApplication` with `ApproveApplication`/`RejectApplication`: single `UPDATE organizer_applications SET status=… WHERE id=$1 AND status='pending'` (approve `RETURNING`), zero rows → `shared.ErrConflict`-typed `application_not_pending` → 409. `service/organizer.go` `Approve`/`Reject` call the guarded methods (no pre-read race); approval + `CreateOrganizer` share the per-request tx (`BeginRequestTx` rolls back on the 500), so organizer-create failure returns the app to `pending`. Tests: `TestApproveConcurrentSingleWinner` (handler, 2 goroutines → one 200 + one 409, single organizer row), `TestApproveRollbackOnOrganizerCreateFailure` (pre-existing slug → 500, app still `pending`), `TestApproveSuccess`/`TestApproveDuplicate`/`TestRejectSuccess`, plus repo-level `TestApproveApplicationConcurrent` (2 tx → one winner + one ErrConflict) and `TestRejectApplicationNonPending`. WS6 audit `docs/multi-step-operations.md` covers Register/SendVerification/VerifyCode/Refresh/Approve/worker MarkSent+MarkFailed: write order, atomicity mechanism, intentional-partial statement each. Gate: gofmt clean · build PASS · vet PASS · `go test -race -p 1 -count=1 ./...` all 16 packages `ok` (handlers 402s, repository 20s — DB-backed vs Neon) · golangci-lint **BLOCKED** (not installed) |
| Auth rate limiting (**phase-05**, 2026-09-06) | **done** | New `middleware/ratelimit.go`: in-memory fixed-window `Limiter` (`sync.Mutex` + `map[string]*bucket`; `Allow(key, limit, window) (ok, retryAfter)`; lazy window reset + janitor goroutine (`prune()`, `Stop()`) so expired state is reclaimed; injectable clock for deterministic tests). `ClientIP` (XFF first value → `RemoteAddr` port-stripped) + `AccountKey` (email from body, lowercased/trimmed, body read-and-restored so handlers still decode). Middleware `RateLimit(l, checks…)` → generic `too_many_requests` 429 + `Retry-After`, no account-existence leak. Wired in `routes.go`: IP bucket on login/register/refresh/verify, account bucket additionally on login/register; config defaults login 20/5m, register 5/1h, refresh 30/5m, verify 20/1h (validation limit>0, window>0 fail-fast). Single shared limiter on `app.RateLimiter` (per-app state → fresh in tests), stopped on `cmd/api` shutdown. Tests: 13 middleware unit tests (limit+1 block, window rollover reset, key independence, Retry-After math, concurrent `-race` safety, janitor prune/stop, ClientIP matrix, email normalization + full-body restore, no-email skip, 429-with-header, IP vs account bucket isolation) + 3 DB-backed burst integration tests (`TestAuthLoginRateLimitIP`, `TestAuthLoginRateLimitAccount` (fresh IP, same account → 429), `TestAuthVerifyRateLimit`). Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 ./...` all 16 packages `ok` (handlers 355s, middleware 6s, config 1s — DB-backed vs Neon) · golangci-lint **BLOCKED** (not installed). Delivery note: in-memory/single-instance choice documented in `config.go`, `ratelimit.go`, README |
| Admin stale-role recheck (**phase-06**, 2026-09-06) | **done** | `middleware/auth.go` `RequireAdmin` now re-verifies the admin role server-side on every admin request: parses token for identity only → obtains the request tx from context → sets RLS context (`SetRLSContextTx(ctx, tx, userID, "admin")`) → fetches the user via `auth.GetUser(ctx, userID)` → requires `user.Role == "admin"`, else 403. JWT role claim is ignored; a demoted admin loses access immediately (no wait for JWT expiry). Non-admin `RequireAuth` path unchanged (JWT claim trusted, max staleness window = `JWT_EXPIRY`, default 15m — documented). Tests: `TestAdminStaleRoleRecheck` (register → promote → login → approve 200 → demote in DB → same old token on approve → 403 immediately; freshly minted post-demotion token → 403; non-admin → 403; unauthenticated → 401). Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 ./...` all 16 packages `ok` (handlers 402s — DB-backed vs Neon) · golangci-lint **BLOCKED** (not installed) |
| Pagination for lists (**phase-07**, 2026-09-06) | **done** | `GET /api/v1/events` and `GET /api/v1/venues` now accept `page` (default 1, ≥1) + `limit` (default 20, 1..100); invalid values → 400 (no silent clamp). Repos: `events.ListVisible(limit,offset)` (`ORDER BY starts_at, id`) + `CountVisible`, `venues.ListActive(limit,offset)` (`ORDER BY name, id`) + `CountActive`. Service: `ListEvents`/`ListVenues(ctx, page, limit) → PageResult{Items, Total}`. Handlers: envelope response `{"data":[…], "pagination":{page,limit,total,has_next}}`; new `dto.PaginationMeta`/`PaginatedResponse[T]`. The `data` array shape is kept (client-facing, spec §4 shape) — documented. Tests (`pagination_test.go`, DB-backed): defaults, custom limit, invalid params (0, 101, negative, non-numeric → 400), stable ordering across pages with no dupes/gaps (7 events @ limit 3), has_next boundary, venue pagination. `organizers_test.go` visibility check updated to `?limit=100` so the just-published event is guaranteed on page 1 when the shared dev DB holds many published events. Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 ./...` PASS (handlers 500s, all 15 non-worker packages green vs Neon; worker BLOCKED — Brevo API returns 400, env dependency) · golangci-lint **BLOCKED** (not installed) |
| Idempotency for retryable writes (**phase-08**, 2026-09-06) | **done** | Migration `00010_idempotency_keys.sql`: `idempotency_keys(id, user_id FK, key, request_hash, operation, status idempotency_status('in_progress','completed'), response_code int, response_body jsonb, created_at, expires_at)`, `UNIQUE(user_id,key)` + user/expires indexes, RLS own-row (`current_app_user_id()`) + privileged, `GRANT` to app_user; applied to Neon (version 10). `repository/idempotency.go`: `Create` (in_progress insert via `INSERT … ON CONFLICT (user_id,key) DO NOTHING` + opportunistic expired-row reap — chosen over a plain INSERT because a racing `23505` **aborts the whole Postgres tx**, breaking the caller's follow-up lookup; DO NOTHING skips cleanly), `Get`, `Complete`. New `middleware.Idempotency(app)` (`middleware/idempotency.go`), opt-in via `Idempotency-Key` header; sha256(method+" "+path+NUL+body) request hash; body read-once-and-restored so the handler decodes the same bytes; runs inside `BeginRequestTx` after auth+RLS so a 2xx response + `completed` record commit atomically and a `>=400` rolls the record back (corrected retry starts fresh); same key+same hash → registered replay of stored status/body, same key+diff hash → `409 idempotency_key_reused`, racing same-key → `409 idempotency_in_progress`; 24h TTL safety valve reaps stale in_progress rows. Wired onto the 3 protected POSTs (`/organizer-applications`, `/venues`, `/events`); deliberately NOT on Publish (status-guarded) or PATCH (idempotent by nature); decision log `docs/idempotency.md` lists protected vs safe-without. Tests: 7 middleware unit tests (no-key pass-through, first-run stores response + body restore, replay-same-request, reused-409, in_progress-409, failed-write-not-recorded, hash determinism) + 2 DB-backed handler tests (sequential matrix: 201 → replay same id no-dup → reused-409 no-create → no-key composes; concurrent: 4 racing same-key → exactly 1 event row, zero 500s, only 201/409). Shared-DB brittleness surfaced during the gate (70 published events exceeded the old 20-page walk cap) → `TestPaginationEventsStableOrder` now derives its termination cap from the stable `total`. Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 ./...` PASS (all 16 packages `ok`, handlers 605s — DB-backed vs Neon) · golangci-lint **BLOCKED** (not installed) |
| Input validation + lean observability (**phase-09**, 2026-09-06) | **done** | WS10: new `handlers/param.go` `ParseUUIDParam(r,"id")` — strict canonical 8-4-4-4-12 regex (`gen_random_uuid()` form, any case), project models ids as strings so it returns the matched string + ok (no uuid dep; deliberately rejects Postgres-isms like braces/grouped hex so a client can't smuggle parse-fragile forms); wired into every UUID path handler (`GetEvent`, `UpdateEvent`, `Publish` in events.go + admin `Approve`/`Reject` in organizer.go) with a new `Application.NotFound` helper writing the generic `404 not_found "cannot find resource"` body **before any DB call** — a malformed `{id}` can never hit Postgres's `22P02` 500 again. WS13: new `internal/api/metrics` package (zero dependencies): `Registry` (`sync.Mutex`-guarded `http_requests_total{method,status}` additive counter buckets, added by `metrics.Count` middleware at the outermost chain edge so RecoverPanic-converted 500s and CORS short-circuits are counted) + `WritePrometheus` rendering Prometheus text format with deterministic ordering and scrape-time runtime gauges from `runtime.ReadMemStats`/`NumGoroutine` (`process_alloc_bytes`, `process_total_alloc_bytes`, `process_gc_count`, `process_goroutines`); `GET /metrics` registered on a non-RLS, no-auth route that never reads the tx context; registry lives on `app.Metrics` (per-app isolation like `RateLimiter`). Tests: 5 `metrics` unit tests (bucket counts, deterministic request-counter output + sorted labels, runtime gauge families, `Count` middleware records implicit-200/201/explicit-500/panic statuses, Content-Type) + DB-free handler checks: `TestMetricsHandlerExposesPrometheusText` (200 + Content-Type `text/plain; version=0.0.4` + expected labels) and `TestInvalidUUIDPathParamsReturn404` (DB-free matrix across all 5 handlers × 4 malformed values, nil services → 404 proves the guard fires first, body carries `not_found`) + DB-backed routes tests: `TestMetricsRouteIsPublicNoAuth` (200 + metric families) and `TestEventMalformedUUIDIs404Not500` (Clean JSON 404, never 500). `TestAuthAndPublicRoutesAreRegistered` premise updated: a registered route now legitimately 404s on a malformed `{id}` (handler-level), so its registration probe uses a well-formed-but-missing UUID. Known out-of-scope wart recorded for a follow-up: a well-formed-but-missing id still reaches the DB and 500s (`ErrNotFound` → `ServerError`; `shared.StatusFor` is unreferenced dead code). Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 ./...` PASS (all 17 packages `ok` incl. new `metrics`, handlers 600s — DB-backed vs Neon) · golangci-lint **BLOCKED** (not installed) |
| Email worker reliability (**phase-10**, 2026-09-06) | **done** | **No production defect found** — the outbox guarantees held under all three failure modes, so the only prod change is a non-behavioral test seam: `EmailConsumer.outbox` is now the `emailOutboxStore` interface (`ClaimBatch`/`MarkSent`/`MarkFailed`) so tests can inject a faulting store at the commit step (`worker/email.go`; `NewEmailConsumer` signature and wiring unchanged). New DB-backed suite `worker/reliability_test.go` (4 tests, all `-race`, vs Neon `service` role): (1) `TestWorkerFailureAfterProviderKeepsRowRetryable` — provider accepts the message then `MarkSent` fails (injected) → row stays `pending`, `attempts` untouched, no committed `sent` log row: at-least-once with no half-written state; (2) `TestWorkerConcurrentClaimSingleSend` — 40 rows, 6 goroutines × repeated `processBatch` → exactly 40 provider calls, each recipient sent exactly once (no double-send via `SKIP LOCKED`), 40 `sent` / 0 `pending` / 0 `failed` rows, 40 distinct `sent` log rows; (3) `TestWorkerLeaseExpiryRecoversClaim` — a worker that claimed then died leaves the row `pending`; after lease expiry (deterministic `next_retry_at` bump, no sleeps) the restart re-claims and delivers exactly once; (4) `TestWorkerGracefulShutdownInterruptedSendStaysRetryable` — `Run` + ctx cancel mid-send: loop stops promptly (`nil`, no hung drain), interrupt leaves the claim `pending`/`attempts 0`/no `sent` log (dead-letter on a cancelled ctx never commits), and recovery after lease delivers once. Graceful-shutdown drain semantics are structural: `Run` is single-goroutine and each batch completes before the next ctx check; an in-flight claim is never half-written because `MarkSent`/`MarkFailed` are single txs. `docs/multi-step-operations.md` §6 cross-refs the suite as the proof of the at-least-once/no-duplicate guarantees. Gate trip handled: the shared dev DB accumulates ~9 published events per run, pushing `handlers` past `go test`'s default 10m timeout (616s) → gate command now carries `-timeout 20m` (`backend/Makefile` `ci` target; CI's local Postgres runs the same suite in seconds and is unaffected). Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 -timeout 20m ./...` PASS (all 17 packages `ok`, handlers 616s) · golangci-lint **BLOCKED** (not installed) |
| Final audit, docs, report (**phase-11**, 2026-09-06) | **done** | Re-audit of the entire changed surface. **Config cross-check**: `config.Load()` reads 29 env vars — all documented in `backend/README.md`; found `CORS_ALLOWED_ORIGINS` missing from both `.env.example` and the README table and 6 worker/email/Brevo vars missing from `.env.example` → all added (`.env.example` 27/29, README 29/29). **Contract audit** (per-route, methods+auth+validation): verify GET→POST-only CONFIRMED (405, no query token, `verify_code` deep-link param), 429 shape CONFIRMED (`Retry-After` + `too_many_requests`), 409 code set CONFIRMED (7 semantic codes, none 500), pagination envelope CONFIRMED (`data`+`pagination{page,limit,total,has_next}`), idempotency replay-verbatim CONFIRMED, no 22P02 500 CONFIRMED, no secret-bearing URLs/logs CONFIRMED. **One code finding fixed**: the last wrong-5xx — a well-formed but nonexistent resource id (e.g. `GET /events/{missing-uuid}`) returned 500 because `AppError` did not map the bare `shared.ErrNotFound` sentinel; `AppError` now consults `shared.StatusFor` (`internal/api/helpers.go` + `sentinelCode/Messages`) → 404 `not_found` / 409 `conflict` (the previously dead `StatusFor` is now wired); new `handlers/not_found_test.go` `TestWellFormedMissingUUIDIs404` (GET/PATCH/publish, DB-backed) proves it; `routes_test.go` registered-route premise strengthened (a registered route's 404 must be a JSON app error, never the mux plain-text 404). **Docs**: `docs/SECURITY_HARDENING_FINAL_REPORT.md` written (findings-by-finding table WS1–WS17 with status/evidence — WS14/WS15/WS16 rows flagged as reconstructed from phase evidence since the original audit doc was not committed; residual risks R1–R5 each have an owner/next-step; deployment checklist). Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 -timeout 20m ./...` PASS (all 17 packages `ok`, handlers 654s) · golangci-lint **BLOCKED** (not installed). **Hardening program complete — all 12 phases done.** |

| API completion 12a (**phase-12a**, 2026-09-07) | **done** | comments CRUD (`internal/repository/comment.go`, service, handlers), users/me PATCH with OptionalAuth, likes toggle (atomic upsert), comments/likes RLS policies + migration. Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 ./...` PASS · golangci-lint **BLOCKED** |
| API completion 12b (**phase-12b**, 2026-09-07) | **done** | save folders + saves (dedup point-in-time), shares (dedup + public share), organizer follows + public profile. Gate: gofmt CLEAN · build PASS · vet PASS · full race suite PASS · golangci-lint **BLOCKED** |
| API completion 12c (**phase-12c**, 2026-09-08) | **done** | RSVP with atomic capacity (`attempt_event_rsvp` SECURITY DEFINER), reviews (ratings + text), reports + moderation_status flow. Gate: gofmt CLEAN · build PASS · vet PASS · full race suite PASS · golangci-lint **BLOCKED** |
| API completion 12d (**phase-12d**, 2026-09-08) | **done** | notification inbox + hooks, event reminders, FTS search filters, venue detail/update, admin moderation endpoints. Gate: gofmt CLEAN · build PASS · vet PASS · full race suite PASS · golangci-lint **BLOCKED** |
| Media pipeline (**phase-13**, 2026-09-08) | **done** | `enqueue_media_job` SECURITY DEFINER, S3/local storage, image variants, worker processing → `/media/{id}` public serving, media RLS + grants. Migration 00015 applied (DB v15); committed `a11cafb`. Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 -timeout 20m ./...` all 17 packages `ok` · golangci-lint **BLOCKED** |
| Tickets & orders (**phase-14**, 2026-09-10) | **done** | Migration `00016_tickets_orders.sql` (ticket_types/orders/order_items/tickets; SECURITY DEFINER `reserve_ticket_inventory`/`release_ticket_inventory`/`check_in_ticket`; currency trigger; RLS + grants) applied → DB v16, SQL-smoke-validated. Domain + repository (`internal/repository/{ticket,order}.go`), `service/order.go` (tier CRUD, atomic reserve order creation, cancel-with-release, `ConfirmPaid` privileged ticket issuance, HMAC payloads, check-in), DTOs, handlers, routes (public/manage tier lists, protected orders/cancel/wallet, organizer check-in), `config.TicketQRSecret`, `docs/ticket-qr-protocol.md`. Tests (`tickets_orders_integration_test.go`): tier CRUD+visibility/deactivate, order lifecycle + check-in (signature re-derivation, duplicate 409, tampered-HMAC/bad-date/cross-event 422, non-organizer 403), oversell race (5-cap, concurrent 3+3 → exactly one 201 + one 409), cancel-then-repurchase, paid-order-not-cancellable (409). Also fixed a shared-DB flake in the phase-12d date-window search (limit=100 so the in-window event stays on page 1). Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 -timeout 20m ./...` all 17 packages `ok` (handlers 751s) · golangci-lint **BLOCKED** (not installed). **⚠️ One env wart surfaced during phase 14: `registerAndToken` slices `prefix[:3]`, so prefixes must be ≥3 chars** — see goldens/gotchas |
| Payments + webhooks (**phase-15**, 2026-09-11) | **done** | Migration `00017_payments.sql` applied → DB v17 (payments ledger + `enforce_payment_currency` trigger + RLS + SECURITY DEFINER `record_pending_payment`; smoke-validated via psql as app_user). New `internal/infrastructure/payments` (Provider interface, Chapa client — initialize/verify + `SignatureValid` HMAC-SHA256 over the raw body with `Chapa-Signature`/`x-chapa-signature` — noop provider, factory; unit-tested), `domain/payment.go`, `repository/payment.go` (RecordPending/UpsertFromWebhook/GetByOrder), `service/payment.go` (Initiate + HandleWebhook), `handlers/payment.go` webhook route under `service(...)`, and card-init wired into `POST /events/{id}/orders`: noop → no `payment` block (dev flow unchanged); chapa → `payment{provider,provider_ref,redirect_url}` in the 201, provider-init failure → `502 payment_unavailable` and `BeginRequestTx` rolls back the order+reservations (no orphan, no leak). Webhook contract: signature → authoritative `provider.Verify` (body status never trusted) → success = `ConfirmPaid` (tickets) + ledger upsert keyed by `tx_ref` + best-effort `ticket` notification; failed = new `FailPayment` (inventory release) + failed ledger row (amount/currency from the order, fallback verify); pending/authorized = no-op; duplicate webhook idempotent; tampered → 401; unknown order → 404. `GET /orders/{id}`/`GET /me/orders` expose `payment_provider`/`provider_ref`. Tests (`payments_webhook_test.go`, fake provider): init+success (redirect block, pending ledger, tickets, paid order + columns, paid ledger, notification, duplicate no-op), tampered/missing signature 401 + non-JSON 400, unknown order 404, failure releases inventory + reorder succeeds, init-failure rollback (no order row, no leaked inventory). Also fixed pre-existing `TestOrganizerVenueEventSlice` flake (uses unique title + `q=` search instead of global page-1). `.env.example` + docs (`docs/chapa.md`). Gate: gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 -timeout 20m ./...` all 17 packages `ok` (handlers 772s, DB-backed vs local `event_nu_test` v17) · golangci-lint **BLOCKED** (not installed) |

Standard gate (run after every slice):
`go build ./...` · `go vet ./...` · `go test -race -p 1 ./...` *(Makefile: `-p 1` required — integration tests share one dev DB)* · `golangci-lint run` *(if available)*

**Last gate run (2026-09-11, after phase-15):** gofmt CLEAN · build PASS · vet PASS · `go test -race -p 1 -count=1 -timeout 20m ./...` PASS (all 17 packages `ok`, handlers 772s; DB-backed tests ran against local `event_nu_test` at v17) · golangci-lint **BLOCKED** (not installed)

---

## 5. Production Readiness Checklist (spec §28)

### Go API
- [ ] Authentication complete
- [ ] Authorization complete
- [ ] All business actions transactional
- [ ] Rate limiting enabled
- [ ] CORS restricted
- [ ] Request limits enabled
- [ ] Structured logs
- [ ] Health/readiness endpoints
- [ ] Graceful shutdown

### Database
- [ ] Neon production project configured
- [ ] Migrations reproducible
- [ ] Backup/restore tested
- [ ] Indexes reviewed
- [ ] RLS policies tested
- [ ] DB roles restricted; no app uses owner credentials

### Email / Brevo
- [ ] Sender `daggi.x02@gmail.com` (technical) verified; `event.nua@gmail.com` user-facing display/reply-to
- [ ] 8 transactional templates created, IDs in `BREVO_TEMPLATE_*` (start: Welcome + Verify)
- [ ] Worker retry/backoff + dead-letter
- [ ] Idempotent order receipts

### Flutter
- [ ] Local DB / offline reads / write outbox / retry / idempotency / conflict handling / secure token storage / push

### Admin
- [ ] Secure login / admin role enforcement / HttpOnly cookie / server-side Prisma only / RLS / audited moderation / business actions via Go

### Media / Payments / Sync
- [ ] R2 + upload authz + size/type validation + worker + retries + CDN + cleanup
- [ ] Provider + server-side verification + webhook signature + duplicate handling + idempotent orders + refund/cancel state
- [ ] Offline read/write/reconnect/duplicate/out-of-order/conflict/authz-after-reconnect tested

---

## 6. Config & Environment Registry

| Var | Status | Notes |
|---|---|---|
| `APP_ENV` | set (development) | `.env` |
| `PORT` | set (8080) | `.env` |
| `DATABASE_ADMIN_URL` | set | owner role; for migrations only |
| `DATABASE_URL` | set (app_user) | **app_user role under RLS**; worker presets role=service |
| `JWT_SECRET` | set | generated; rotate for prod |
| `JWT_EXPIRY` / `REFRESH_TOKEN_EXPIRY` | set | `.env` |
| `BREVO_API_KEY` | set | `.env` — rotate before prod; never commit/chat |
| `BREVO_SENDER_EMAIL` | set (event.nua@gmail.com) | `.env` — user-facing display/reply-to |
| `BREVO_API_SENDER` | set (daggi.x02@gmail.com) | verified active Brevo sender (id 2) → technical From; reply-to = `event.nua@gmail.com` |
| `BREVO_SENDER_NAME` | set (Event Nu) | `.env` |
| `EMAIL_PROVIDER` | set (brevo) | `.env` |
| `BREVO_TEMPLATE_*` (8) | **2/8 done** | Welcome=**3**, Verify=**4** — re-validated active via MCP 2026-09-02; 6 remaining (OTP, Password Reset, Login Alert, Order Receipt, Admin Application, Admin Report). Config **fails fast** if unset with `EMAIL_PROVIDER=brevo` (`6801c2f`) |
| `EMAIL_PROVIDER` | noop used for E2E/test | `.env` sets brevo |
| `EMAIL_POLL_INTERVAL` / `BATCH_SIZE` / `MAX_ATTEMPTS` | set (2s/20/3) | worker config defaults |
| `EMAIL_RETRY_BASE_DELAY` | set (30s) | worker backoff base |
| `TICKET_QR_SECRET` | set | `.env` — signs check-in QR HMAC payloads (fallback `JWT_SECRET`) |
| `PAYMENT_PROVIDER` | default `noop` | `chapa` enables checkouts/webhooks; anything else → NoopProvider (never charges money) |
| `CHAPA_SECRET_KEY` | unset (noop) | required when `PAYMENT_PROVIDER=chapa`; authenticate initialize/verify calls |
| `CHAPA_API_BASE` | default `https://api.chapa.co/v1` | override for sandbox/mock |
| `CHAPA_WEBHOOK_SECRET` | default = `CHAPA_SECRET_KEY` | verifies webhook HMAC signatures |
| `CHAPA_REDIRECT_BASE` | default = `APIPUBLICBASE` | return_url sent to Chapa |
| Relay / transactional sending | **BLOCKED** | SMTP relay `enabled:false`; send → 403 `"Your SMTP account is not yet activated"`; re-verified via MCP 2026-09-02 (org `6a969ac23190bd578e038837`, free 300/day) |

---

## 7. Blockers & Open Items

- [x] Brevo sender `daggi.x02@gmail.com` verification — **active (id 2), verified 2026-09-02**.
- [ ] Brevo template IDs (Welcome + Verify) → `BREVO_TEMPLATE_*`. — **2/8 done: Welcome=3, Verify=4**
- [ ] **Brevo SMTP activation** — Brevo returns `403 "Your SMTP account is not yet activated"`. Enable transactional sending in the dashboard or contact Brevo support. **Re-verified 2026-09-02: relay still `enabled:false`.**
- [ ] Leftover dev `eventnu-api` process still bound to `:8080` (pid 178591) — stop when done.
- [ ] Create `app_user` DB role; point `DATABASE_URL` at it — **DONE (2026-09-01)**
- [ ] Confirm pgx v5.5+ for `channel_binding=require`.
- [ ] Production sender deliverability — consider verified custom domain.
- [ ] Keys hygiene — keep Neon password + Brevo key out of git/chat.
