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
| 5 | Brevo email (outbox, worker, welcome + verify) | not started | — |
| 6 | RLS context (SET LOCAL, app_user role) | not started | — |
| 7 | First product slice (organizer applications → venues → categories → events → discovery) | not started | — |

**First milestone (definition of done):**
register → login → profile → organizer application → admin approval → create event → publish → discovery → event details → real venue → navigation.

---

## 2. Phase Tracker (spec §23 / plan §4)

Current phase: **4 — Authentication** (auth slice done; email integration next).

| Phase | Area | Status |
|---|---|---|
| 0 | Product/architecture contract | **done** (spec v3) |
| 1 | Repository foundation | **done** (2026-09-01) |
| 2 | Neon DB foundation | **done** — migrations 00001/00002 applied |
| 3 | Go API foundation | **done** — healthz/readyz, middleware, server |
| 4 | Authentication | **done** — register/login/refresh/logout + /me, tests PASS |
| 5 | RLS context | not started |
| 6 | Flutter offline foundation | not started |
| 7 | Users and profiles | not started |
| 8 | Organizer applications | not started |
| 9 | Venues and categories | not started |
| 10 | Events/posts + lifecycle | not started |
| 11 | Media (R2) | not started |
| 12 | Discovery/search | not started |
| 13 | Social | not started |
| 14 | RSVP | not started |
| 15 | Tickets + orders + payments | not started |
| 16 | Reviews/ratings | not started |
| 17 | Reporting + moderation | not started |
| 18 | Notifications + reminders | not started |
| 19 | Next.js admin | not started |
| 20 | Prisma + admin RLS | not started |
| 21 | Full offline sync | not started |
| 22 | Production hardening | not started |
| 23 | Testing (all layers) | partial — auth matrix + middleware + service done |
| 24 | Production deployment | not started |
| 25–29 | Hardening / observability / deploy / verify | not started |

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
| Unit | **done** | service (JWT round-trip, hash, validation), shared JSON helpers, config fail-fast |
| Integration | **done** | full auth flow matrix vs real Neon DB (register/login/refresh-rotation/logout/me) |
| Repository | **done** (auth) | exercised via integration tests; NULL-safe user scan, constraint-aware errors |
| HTTP handler | **done** (auth) | httptest matrix incl. malformed input, boundary values, authz |
| Authorization / RLS | not started | — |
| Offline sync | not started | — |
| End-to-end | **done** (auth) | live smoke via running server |
| Load / performance | not started | — |
| Payment / webhook | not started | — |
| Worker / job recovery | not started | — |

Standard gate (run after every slice):
`go build ./...` · `go vet ./...` · `go test -race ./...` · `golangci-lint run` *(if available)*

**Last gate run (auth slice):** build PASS · vet PASS · `go test -race ./...` PASS · golangci-lint **BLOCKED** (not installed)

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
| `DATABASE_URL` | set (temp: mirrors owner) | **swap to `app_user` before production — owner bypasses RLS** |
| `JWT_SECRET` | set | generated; rotate for prod |
| `JWT_EXPIRY` / `REFRESH_TOKEN_EXPIRY` | set | `.env` |
| `BREVO_API_KEY` | set | `.env` (ignored) — **rotate** (exposed in chat this session) |
| `BREVO_SENDER_EMAIL` | set (event.nua@gmail.com) | `.env` — user-facing display/reply-to |
| `BREVO_API_SENDER` | **pending** (daggi.x02@gmail.com) | verified technical sender |
| `BREVO_SENDER_NAME` | set (Event Nu) | `.env` |
| `EMAIL_PROVIDER` | set (brevo) | `.env` |
| `BREVO_TEMPLATE_*` (8) | **pending** | create templates in dashboard, then add |
| `ADMIN_ALERT_EMAILS` | **pending** | — |
| `EMAIL_POLL_INTERVAL` / `BATCH_SIZE` / `MAX_ATTEMPTS` | **pending** | worker config |

---

## 7. Blockers & Open Items

- [ ] Brevo sender `daggi.x02@gmail.com` verification (before first real send).
- [ ] Brevo template IDs (Welcome + Verify) → `BREVO_TEMPLATE_*`.
- [ ] Create `app_user` DB role; point `DATABASE_URL` at it.
- [ ] Confirm pgx v5.5+ for `channel_binding=require`.
- [ ] Production sender deliverability — consider verified custom domain.
- [ ] Keys hygiene — keep Neon password + Brevo key out of git/chat.
