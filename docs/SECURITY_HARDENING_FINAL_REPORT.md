# Event Nu — Security Hardening Final Report

Date: 2026-09-06 · Branch: `main` · Scope: `backend/` hardening phases 00–11

## 1. Executive summary

The hardening program ran 12 sequential phases (00–11) on `main`, each with an
honest verification gate. All concrete security findings were fixed or
explicitly documented; the final audit (phase-11) re-checked the whole changed
surface, closed one remaining status-code inconsistency, and fixed two
documentation gaps. The full gate passes at phase-11 commit: gofmt clean, build
PASS, vet PASS, `go test -race -p 1 -count=1 -timeout 20m ./...` PASS across
all 17 packages (140 test functions). `golangci-lint` remains **BLOCKED** (not
installed in this environment — a documented residual risk).

No secrets exist in the repository; `.env` is git-ignored; all configuration
is injected via environment; error responses never expose internals; paths and
logs carry no query strings or credentials.

## 2. Findings outcome table

Source note: the original audit that produced the `WS#` weakness ids was a
session artifact and was **not committed to this repository**. Rows WS1–WS13,
WS15, WS17 derive from phase titles/PLANs and their in-repo evidence. Rows
WS14, WS16 and part of WS15 are **reconstructed from the phase-11 plan and this
audit's evidence** and are flagged as such:

| WS | Finding (name/scope) | Status | Evidence |
|----|----------------------|--------|----------|
| WS1 | Refresh token rotation not atomic (read-then-revoke race) | **Fixed** | phase-03: `ConsumeForRotation` single `UPDATE…RETURNING` (`repository/session.go`); refresh consumes then issues inside one request tx; concurrent repo + handler tests prove exactly-one-winner |
| WS2 | No rate limiting on auth endpoints | **Fixed** | phase-05: in-memory fixed-window limiter (`middleware/ratelimit.go`) on the 4 auth routes; IP bucket + account bucket on login/register; config-driven defaults; 13 unit + 3 DB-backed burst tests |
| WS3 | Login timing leaks account existence | **Fixed** | phase-02: dummy bcrypt burn on unknown email equalizes timing; proof-by-count test |
| WS4 | Verify token in URL + query strings logged | **Fixed** | phase-02: `GET verify` route removed (405), POST body + `eventnu://verify` deep link carry code; `LogRequest` logs `method`/`path` only — no query, no headers (`middleware/middleware.go`, proven by `TestLogRequestRedactsQueryString`) |
| WS5 | Organizer approval read-then-update race | **Fixed** | phase-04: single `UPDATE…WHERE status='pending'` guard; zero rows → `409 application_not_pending`; approval + organizer-create share the request tx (rollback to `pending` on failure) |
| WS6 | Multi-step writes not audited | **Fixed** | phase-04: `docs/multi-step-operations.md` §"every multi-write op": refresh rotate, verify+login, approve+create-organizer, outbox worker claim/send/mark (cross-ref to phase-10 suite) |
| WS7 | Admin role not rechecked per call | **Fixed** | phase-06: `RequireAdmin` re-verifies the role on every admin action against the DB row, not a token claim |
| WS8 | Public list endpoints unpaginated / unstable walk | **Fixed** | phase-07: `{"data":[…],"pagination":{page,limit,total,has_next}}` envelope; total derived from stable count; walk capped by total; bad params → 400 |
| WS9 | Client-retryable writes not idempotent | **Fixed** | phase-08: `Idempotency-Key` on `POST organizer-applications | venues | events`; `INSERT…ON CONFLICT DO NOTHING` + replay-verbatim (original status, e.g. 201); `409 idempotency_key_reused` / `idempotency_in_progress`; migration `00010_idempotency_keys.sql`; docs/idempotency.md |
| WS10 | Path params unvalidated (Postgres cast 500) | **Fixed** | phase-09: `ParseUUIDParam` regex on all 5 `{id}` handlers; malformed → JSON `404 not_found` before any DB access; DB-free matrix test; no non-UUID path params exist (routes re-audited phase-11) |
| WS11 | Toolchain version drift | **Fixed** | phase-00: local go 1.26.6 = `backend/go.mod`; documented in README |
| WS12 | No CI quality gates | **Fixed** | phase-01: `.github/workflows/ci.yml` + `make ci`; proven against `postgres:16` container |
| WS13 | No lean observability / PII in logs | **Fixed** | phase-09: `GET /metrics` (Prometheus text, no-PII, public, non-RLS); `LogRequest` path-only (WS4 row) |
| WS14 | *Reconstructed* — env/config documentation drift | **Fixed (phase-11)** | cross-check found `CORS_ALLOWED_ORIGINS` missing from both `.env.example` and the README table, and 6 worker/email vars missing from `.env.example`; all 7 added, README row added; see §4 table |
| WS15 | SMS notification path (would need same outbox+guard pattern) | **Low & accepted** | *Definition not in repo — inferred from phase-11 plan.* No SMS code exists in the tree. When SMS is added it must reuse the email outbox + idempotency pattern (owner: feature team; see §7) |
| WS16 | *Reconstructed* — external status-code consistency for non-AppError sentinels | **Fixed (phase-11)** | `AppError` now maps bare `shared.ErrNotFound`→404 and `ErrConflict`→409 via `shared.StatusFor` (`internal/api/helpers.go`); well-formed missing UUID no longer 500s (was the last code-path 500 for client errors); proven by `TestWellFormedMissingUUIDIs404` |
| WS17 | Email worker reliability unproven | **Fixed** | phase-10: `emailOutboxStore` test seam (only prod change); 4 DB-backed tests prove at-least-once + no double-send under provider-commit failure, 40×6 concurrency, lease expiry, graceful shutdown |

## 3. Contract audit (phase-11 task 3)

Per-route audit (method · path · auth):

| Method | Path | Auth | UUID-validated |
|---|---|---|---|
| GET | `/healthz`, `/readyz`, `/metrics` | public | — |
| POST | `/api/v1/auth/register`, `/login`, `/refresh`, `/verify`, `/logout` | service (+rate-limit) | — |
| GET | `/api/v1/venues`, `/categories`, `/events` | public, RLS user | — |
| GET | `/api/v1/events/{id}` | public | yes |
| GET | `/api/v1/users/me` | protected | — |
| POST | `/api/v1/organizer-applications`, `/venues`, `/events` | protected + idempotency | — |
| GET | `/api/v1/organizer-applications/me` | protected | — |
| PATCH | `/api/v1/events/{id}` | protected | yes |
| POST | `/api/v1/events/{id}/publish` | protected | yes |
| POST | `/api/v1/admin/organizer-applications/{id}/approve|/reject` | admin | yes |

Contract claims verified at phase-11:

- **Verify is GET→POST-only**: CONFIRMED — no GET verify route (405), code in POST body, `verify_code` param on the `eventnu://verify` deep link (no secret in any URL).
- **Pagination envelope**: CONFIRMED — `{"data":[…],"pagination":{page,limit,total,has_next}}`; walk bounded by stable `total`.
- **429 shape**: CONFIRMED — `Retry-After` + `{"error":{"code":"too_many_requests"}}`.
- **409 bodies**: CONFIRMED set — `application_not_pending` (approve/reject), `event_not_draft`, `email_taken`, `username_taken`, `application_pending`, `idempotency_key_reused`, `idempotency_in_progress`; all semantic, none 500s.
- **Idempotency replay**: CONFIRMED — replay returns the *original* status verbatim (201 for creates), not a forced 200; documented in docs/idempotency.md.
- **No 22P02 500**: CONFIRMED — all `{id}` params validated; malformed → 404 before DB. Missing (well-formed) resource: **now 404 too** (phase-11 sentinel mapping).
- **No secret-bearing URLs/logs**: CONFIRMED — logs carry `method`+`path` only; no query string, no auth headers; verify link carries email+code only.

## 4. Configuration cross-check (phase-11 task 2)

`config.Load()` reads 29 env vars. Result: all 29 documented in `backend/README.md` (table); 27 of 29 present in `.env.example` after this fix.

| Var | README | `.env.example` (after fix) |
|---|---|---|
| `APP_ENV`, `PORT`, `DATABASE_URL`, `DATABASE_ADMIN_URL`, `JWT_SECRET`, `JWT_EXPIRY`, `REFRESH_TOKEN_EXPIRY`, `EMAIL_PROVIDER` | ✓ | ✓ |
| `BREVO_API_KEY`, `BREVO_API_SENDER`, `BREVO_SENDER_EMAIL`, `BREVO_SENDER_NAME`, `BREVO_TEMPLATE_WELCOME`, `BREVO_TEMPLATE_VERIFY` | ✓ | ✓ |
| `AUTH_{LOGIN,REGISTER,REFRESH,VERIFY}_RATE_{LIMIT,WINDOW}` | ✓ | ✓ |
| `CORS_ALLOWED_ORIGINS` | ✓ *added* | ✓ *added* |
| `EMAIL_POLL_INTERVAL`, `EMAIL_BATCH_SIZE`, `EMAIL_MAX_ATTEMPTS`, `EMAIL_RETRY_BASE_DELAY` | ✓ | ✓ *added* |
| `BREVO_API_BASE`, `API_PUBLIC_BASE` | ✓ | ✓ *added* |

No legacy/unknown vars are documented as live. `.env` remains git-ignored.

## 5. Tests added per phase

Phase-11 audit verified 140 top-level `func Test` in the backend. Suites by
phase (primary files):

| Phase | Suite | Count |
|---|---|---|
| 02 | timing equalization, verify 405, log redaction | 3 |
| 03 | concurrent refresh rotation (repo + handler) | 4 |
| 04 | approval matrix + concurrent one-winner | 5 |
| 05 | rate-limit unit + burst integration | 16 |
| 06 | admin role recheck | 2 |
| 07 | pagination envelope/validation/stability | 6 |
| 08 | idempotency unit + concurrent DB-backed | 9 |
| 09 | UUID validation matrix + metrics unit/route | 11 |
| 10 | email worker reliability (DB-backed, `-race`) | 4 |
| 11 | well-formed missing UUID → 404 (new) | 1 |

## 6. Verification gate (phase-11, real output)

All from `backend/` against the shared dev DB (Neon):

```
gofmt -l .                                        → (empty) CLEAN
go build ./...                                    → PASS
go vet ./...                                      → PASS
go test -race -p 1 -count=1 -timeout 20m ./...    → PASS (all 17 packages ok;
    handlers 653.9s; worker 113.8s; repository 13.3s; service 22.4s; routes 41.1s)
golangci-lint run                                 → **BLOCKED** (not installed)
```

`-timeout 20m` added at phase-10: the shared dev DB grows ~9 published events
per run, pushing the DB-backed handlers suite past `go test`'s 10m default;
CI's local Postgres runs the same suite in seconds and is unaffected.

## 7. Residual risks (owner / next step)

| # | Risk | Treated | Owner / next step |
|---|------|---------|-------------------|
| R1 | In-memory rate limiter is single-instance; scaling to N instances splits the buckets | **Documented decision** (code + README) | Replace with Redis fixed-window when >1 instance (oportunity owner: ops) |
| R2 | `golangci-lint` never ran (not installed) | **BLOCKED**, recorded every phase | Install `golangci-lint` and run `golangci-lint run ./...`; fix anything it flags |
| R3 | SMS notification path (WS15) has no outbox/guard | **Low & accepted** (no SMS code) | Reuse the email outbox + idempotency pattern before any SMS integration |
| R4 | Idempotency window is 24h; expiry re-opens the operation | **Documented** (docs/idempotency.md) | Clients needing longer windows must regenerate keys; consider configurable TTL |
| R5 | Verify deep-link uses a hash-then-lookup of a 6-digit code (no rate cap on brute force beyond verify limiter 20/1h) | **Documented** | Rate window is deliberate; revisit if scanning campaigns emerge |

## 8. Deployment checklist

1. Apply migrations in order up to `00010_idempotency_keys.sql` (`make migrate-up`).
2. Set env per `.env.example` (all 29 vars verified; `DATABASE_URL` uses the RLS `app_user` role, `DATABASE_ADMIN_URL` the owner role).
3. Run the worker as **exactly one instance** (SKIP LOCKED batch lifecycle; see phase-10 + `docs/multi-step-operations.md` §6).
4. If >1 API instance: adopt Redis rate limiting first (R1).
5. Configure Brevo only in production; `EMAIL_PROVIDER=noop` elsewhere (fail-fast guards enforced in config.Load).
6. Point `API_PUBLIC_BASE` at the real client origin so `eventnu://` deep-link code delivery works.
7. After deploy: hit `/metrics`, verify `http_requests_total` appearing; `-race` isn't a prod flag, run without it.
8. Eventually: run `golangci-lint run`, wire it into `make ci` + CI (R2).

## 9. Definition of Done

- [x] Every original finding resolved or explicitly documented with evidence (§2; WS14/WS16/WS15 rows flagged as reconstructed).
- [x] Docs consistent: README (env table + auth contract), PROGRESS, multi-step-operations, idempotency, this report.
- [x] Final report written at `docs/SECURITY_HARDENING_FINAL_REPORT.md`.
- [x] All work committed on `main`; summary presented to the user.