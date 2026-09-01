# Event Nu — Implementation Plan

**Status:** Live working plan — supersedes nothing; complements `EVENT_NU_IMPLEMENTATION_DOCUMENTATION_v3.md` (the master spec).
**Date:** 2026-09-01
**Repo:** `github.com/daggix02-m/event_nu` (currently empty remote)
**Companion:** `docs/PROGRESS.md` (living status/tracker)

---

## 1. Current State

- Workspace contains only `docs/` (spec + target schema) plus `.env`, `.env.example`, `.gitignore`.
- GitHub remote `daggix02-m/event_nu` exists and is **empty**.
- No Go code exists yet. Implementation is treated as building from scratch against the target architecture — not "completing TODO stubs" (the scaffold described in spec §25 does **not** exist in this workspace).
- `git init` not yet run locally.

---

## 2. Locked Decisions

| Area | Decision |
|---|---|
| Module path | `github.com/daggix02-m/event_nu/backend` |
| Go version | 1.26 (stdlib `http.ServeMux` method+path routing; no third-party router) |
| DB driver | pgx v5 (requires `channel_binding=require` support — use a recent v5) |
| Migrations | **goose**, run via `go run github.com/pressly/goose/v3/cmd/goose@latest` |
| Schema | Applied **incrementally** per vertical slice, derived from `EVENT_NU_TARGET_SCHEMA_v3.sql` — never as one 1143-line migration |
| Auth | Custom JWT via `golang-jwt/jwt/v5`; refresh token stored **hashed** in `auth_sessions` |
| Email | **Hand-rolled Brevo client** on `net/http` (`POST /v3/smtp/email`, `api-key` header, templateId + params); no SDK |
| Email content | **Brevo dashboard templates** (HTML lives in Brevo, not Go) |
| Email delivery | **Async via worker queue** (transactional outbox), not blocking in-request |
| Email sender (user-facing) | `event.nua@gmail.com` (display From / reply-to — brand-facing) |
| Email sender (technical) | `daggi.x02@gmail.com` (verified Brevo sending address; accept `@brevosend.com` replacement for dev) |
| Email verification delivery | **Clickable link** via `{{params.verify_url}}` → Go `POST /auth/verify` (no numeric code entry) |
| DB roles | `app_user` (API/worker), `worker_role`, `admin_dashboard`; RLS is defense-in-depth, Go remains primary authz (spec §10) |
| Layering | Handler → Service → Repository; SQL only in repository layer (spec §4.1–4.3) |
| Errors | Wrapped with `%w`, centralized through shared helpers |
| Logging | `log/slog`, leveled, injected via `application` struct |
| Server | Explicit Read/Write/Idle timeouts + graceful shutdown on SIGINT/SIGTERM |

---

## 3. Milestone 1 — "Boot, auth, Brevo email" (first deliverable)

### Step 1 — Repo bootstrap
- `git init`, branch `main`, `remote add origin https://github.com/daggix02-m/event_nu`.
- First commit: `docs/`, `.gitignore`, `.env.example`. **Never commit `.env`.**
- Layout (per spec §26) at monorepo root:
  ```
  backend/
  ├── cmd/api/            # HTTP entry point — wiring only
  ├── cmd/worker/         # background worker entry point
  ├── internal/
  │   ├── config/
  │   ├── api/{routes,handlers,middleware,dto}/
  │   ├── service/
  │   ├── repository/
  │   ├── infrastructure/{database,email}/
  │   ├── domain/
  │   └── shared/
  ├── migrations/
  ├── Makefile
  └── go.mod
  ```
- `Makefile` targets: `run`, `worker`, `test`, `vet`, `migrate-up`, `migrate-new`.
- **Gate:** `go build ./...` passes; commit contains no secrets.

### Step 2 — Foundation boots (spec Phase 3)
- `internal/config`: read `.env` (godotenv, cmd only), validate, **fail fast** on `DATABASE_URL`, `DATABASE_ADMIN_URL`, `JWT_SECRET`, `BREVO_API_KEY`.
- `application` struct (slog logger, pgx pool, config); stdlib router.
- Middleware chain: `recoverPanic → requestID → logRequest → secureHeaders → CORS`.
- Server: `ReadTimeout 5s / WriteTimeout 10s / IdleTimeout 1m`; graceful shutdown.
- Endpoints: `GET /healthz` (liveness), `GET /readyz` (DB ping).
- **Gate:** `go build ./...` + `go vet ./...` pass; `/healthz` returns 200.

### Step 3 — DB + migrations (incremental, via goose, `DATABASE_ADMIN_URL`)
- `00001_core.sql`: extensions (`pgcrypto`), enums (`user_role`, `user_status`, `magic_link_purpose`), `users`.
- `00002_auth.sql`: `auth_sessions`, `magic_link_tokens`.
- **Gate:** clean DB built entirely from migrations; `/readyz` green.

### Step 4 — Auth vertical slice (spec Phase 4)
- `users` repository → auth service (bcrypt; `golang-jwt/jwt/v5` access token; refresh hashed in `auth_sessions`) → handlers.
- Endpoints: `POST /auth/register|login|refresh|logout`, `GET /users/me`; auth middleware on protected routes.
- Full test matrix with `-race` (unauthenticated, wrong creds, malformed input, boundary values).
- **Gate:** register → login → `/me` round-trips end-to-end.

### Step 5 — Brevo email (spec Phase 4 subset)
- `00003_email.sql`: `email_codes`, `email_outbox`, `email_logs`.
- `internal/infrastructure/email`: hand-rolled Brevo client (retry/backoff on 429/5xx) + `noop` provider for tests.
- `cmd/worker`: email consumer (`FOR UPDATE SKIP LOCKED`, backoff, graceful shutdown).
- Wire **welcome** + **email verification** on register; `POST /auth/verify` consumes the hashed code from `email_codes`.
- **Gate:** real send to `event.nua@gmail.com` verified against Brevo (reported **BLOCKED** if keys/network unreachable).

### Step 6 — RLS context (spec Phase 5)
- Transaction-local `SET LOCAL app.user_id / app.role / app.organizer_id` helper.
- Create `app_user` role in Neon; swap `DATABASE_URL` to it (owner-mirror is temporary only).
- **Gate:** a user cannot read another user's protected rows even if app-layer authz has a bug.

### Step 7 — First product slice (spec Phases 8–10)
- Organizer applications (migration → repo → service → handler → route → tests), then venues → categories → events → publish → discovery.
- Each slice lands as a full verified vertical slice; **never** all handlers, then all models, then all tests.
- **Gate (first milestone complete):** register → login → profile → organizer application → admin approval → create event → publish → discovery → event details → real venue → navigation.

---

## 4. Full Roadmap (spec §23 phases, summarized)

Spec order is authoritative; build dependency-ordered, not UI-ordered.

| Phase | Area | Status |
|---|---|---|
| 0 | Product/architecture contract | done (spec v3) |
| 1 | Repository foundation | Milestone 1, Step 1 |
| 2 | Neon DB foundation | Milestone 1, Step 3 |
| 3 | Go API foundation | Milestone 1, Step 2 |
| 4 | Authentication | Milestone 1, Step 4 |
| 5 | RLS context | Milestone 1, Step 6 |
| 6 | Flutter offline foundation | later |
| 7 | Users and profiles | later |
| 8 | Organizer applications | Milestone 1, Step 7 |
| 9 | Venues and categories | Milestone 1, Step 7 |
| 10 | Events/posts + lifecycle | Milestone 1, Step 7 |
| 11 | Media (R2) | later |
| 12 | Discovery/search | later |
| 13 | Social (likes/saves/follows/comments) | later |
| 14 | RSVP | later |
| 15 | Tickets + orders + payments | later |
| 16 | Reviews/ratings | later |
| 17 | Reporting + moderation | later |
| 18 | Notifications + reminders | later |
| 19 | Next.js admin | later |
| 20 | Prisma + admin RLS | later |
| 21 | Full offline sync | later |
| 22 | Production hardening | later |
| 23 | **Testing (all layers)** | see §6 |
| 24 | **Production deployment** | see §7 |
| 25–29 | Hardening / observability / deploy / verify | see §7 |

---

## 5. Definition of Done per Slice (spec §27)

A feature is complete only when **all** of these exist:

- **Database:** migration + constraints + indexes + RLS.
- **Backend:** entity + repository + service + handler + validation + authorization + errors + idempotency (where needed).
- **Flutter:** local model + offline behavior + sync behavior + UI state + error handling (when applicable).
- **Admin:** dashboard UI + Prisma query + Go business action + RLS + audit trail (when applicable).
- **Testing:** unit + integration + authorization + offline tests.
- **Operations:** logging + monitoring + failure recovery.

---

## 6. Testing Strategy (spec Phase 23)

Required layers:
`Unit → Integration → Repository → HTTP handler → Authorization/RLS → Offline sync → End-to-end → Load/performance → Payment/webhook → Worker/job recovery`

Critical authorization matrix to test:

| Operation | User | Organizer | Admin |
|---|---:|---:|---:|
| Read published event | yes | yes | yes |
| Create event | no | yes | yes |
| Edit own event | no | yes | yes |
| Edit another organizer's event | no | no | yes |
| Block event | no | no | yes |
| Apply as organizer | yes | no | yes |
| Approve organizer | no | no | yes |
| Report event | yes | yes | yes |
| Manage own profile | yes | yes | yes |
| Manage another user | no | no | yes |
| Review event | eligible | eligible | moderation |

Every state-changing HTTP request is tested, including the full auth/authorization matrix. The **email integration** is tested via a fake Brevo server (`httptest`) asserting payload shape and 429/5xx retry → `failed` after max attempts; handlers assert an outbox row is enqueued, never a real Brevo call.

---

## 7. Production Readiness (spec Phase 24 + §28)

### Go API
- [ ] Authentication complete (register/login/refresh/logout, verification)
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
- [ ] Indexes reviewed (`EXPLAIN ANALYZE`)
- [ ] RLS policies tested
- [ ] DB roles restricted; **no app uses owner credentials**

### Email / Brevo
- [ ] Sender `daggi.x02@gmail.com` (technical) verified in Brevo dashboard
- [ ] 8 transactional templates created (Welcome, Verify, OTP, Password Reset, Login Alert, Order Receipt, Admin Application, Admin Report) → IDs into `BREVO_TEMPLATE_*`
- [ ] User-facing sender `event.nua@gmail.com` (display/reply-to)
- [ ] Worker retry/backoff + dead-letter (`failed` after max attempts)
- [ ] Idempotency keys guarantee exactly-once order receipts

### Deployment
- Flutter → App Store / Play Store
- Next.js admin → Vercel
- Go API → production container platform (provider independent)
- Go worker → separate worker container
- Neon → production PostgreSQL
- Cloudflare R2 → object storage

---

## 8. Open Items / Blockers

- [ ] **Brevo sender verification** — confirm `daggi.x02@gmail.com` (technical sender) in the Brevo dashboard before first real send; `event.nua@gmail.com` is user-facing display/reply-to.
- [ ] **Brevo template IDs** — create 8 templates (start with **Welcome** + **Verify**), feed IDs via `BREVO_TEMPLATE_*` env.
- [ ] **`app_user` role** — **done (2026-09-01)**; `DATABASE_URL` now uses it under RLS; worker presets `role=service`.
- [ ] **`channel_binding=require`** — owner URL only; pgx v5.10 in use (supported).
- [ ] **Deliverability** — Gmail as Brevo sender risks spam filtering; consider a verified custom domain (e.g. `no-reply@eventnua.com`) for production while keeping `event.nua@gmail.com` as reply-to.
- [ ] **Keys hygiene** — Neon password + Brevo key in `.env` (ignored). Brevo API key was pasted in chat twice (this session) — **rotate it** in the Brevo dashboard and update `.env`. Admin credentials shared in chat were discarded; change that password.
