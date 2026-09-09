# EVENT_NU — Backend Feature & Integration Map

**Scope:** Maps every feature, every page, and everything the Go REST API
provides to the Flutter mobile frontend.

**Status legend**
- **🟢 LIVE** — implemented in the Go API today.
- **🟡 PLANNED** — specified in design/schema docs but **no backend endpoint
  exists yet**.

**Source of truth for this document:**
- `backend/internal/api/routes/routes.go` — the live route table
- `backend/internal/api/dto/*.go` — request/response DTO shapes
- `backend/internal/api/handlers/*.go` — handler logic per endpoint
- `flutter/EVENT_NU_FLUTTER_BACKEND_INTEGRATION.md` — Flutter ↔ backend contract
- `docs/EVENT_NU_TARGET_SCHEMA_v3.sql` — target schema (incl. unimplemented tables)

---

## 1. System Architecture

```
Regular User / Organizer
          │
          ▼
     Flutter App
          │ HTTPS / JSON  →  /api/v1...
          ▼
      Go REST API  (backend/cmd/api)
          │
     ┌────┴─────┐
     ▼          ▼
   Neon       Worker (backend/cmd/worker)
 PostgreSQL    → email outbox consumer → Brevo
     │
     └── RLS / constraints

Admin → Next.js Admin → Go auth/API + Prisma → Neon
```

**Responsibility split:**

| Layer | Owns |
|-------|------|
| **Flutter** | Presentation, navigation, local state, caching, offline storage, sync, optimistic UI, device capabilities, notifications, deep links |
| **Go API** | Authentication, authorization, business rules, validation, transactions, moderation, event lifecycle, organizer approval, authoritative server state |
| **Neon/Postgres** | Durable source of truth, guarded by Row-Level Security (RLS) |
| **Worker** | Asynchronous transactional email delivery (outbox pattern) |

**Hard rule:** Flutter must never bypass the Go API to reach PostgreSQL, RLS,
or the database directly. The security chain is always
`Flutter → Go auth → Go authorization → DB access → PostgreSQL RLS`.

---

## 2. HTTP / API Contract

- **Base path:** `/api/v1`
- **All bodies are JSON.** Unknown JSON fields are **rejected** by the backend —
  Flutter must send only documented fields.
- **Request body cap:** 1 MiB.

### Response envelopes

**Success** (single resource / non-paginated):

```json
{ "data": "...", "pagination": { "page": 1, "limit": 20, "total": 137, "has_next": true } }
```

**Paginated** (events, venues):

```json
{
  "data": [...],
  "pagination": { "page": 1, "limit": 20, "total": 137, "has_next": true }
}
```

**Error:**

```json
{ "error": { "code": "some_error", "message": "Human readable message" } }
```

The API client should unwrap the envelope centrally. UI code should not parse
raw response shapes independently.

> Note: a few endpoints return flat `{"data": { ...map/intrinsic... }}`-shaped
> bodies (e.g. logout returns `{"data":{"status":"logged_out"}}`, verify returns
> `{"data":{"verified":true}}`) — the shape is always the `{"data": ...}` envelope.

### Pagination rules

- Default `page = 1`, `limit = 20`; maximum `limit = 100`.
- Use `pagination.has_next` to decide whether another page exists.
- Never use `items.length < limit` as the authoritative pagination test.
- Client should prevent duplicate concurrent page loads.

---

## 3. Endpoint Catalog

All 22 routes currently registered (`routes.go`). **All are 🟢 LIVE.**

### 3.1 Health & Ops (no auth)

| Method | Path | Purpose | Auth | Notes |
|--------|------|---------|------|-------|
| GET | `/healthz` | Liveness probe → `{"status":"ok"}` | none | never touches DB |
| GET | `/readyz` | Readiness probe → `{"status":"ready"}` or 503 `unavailable` if DB unreachable | none | pings DB (3s timeout) |
| GET | `/metrics` | Prometheus text metrics | none | outside auth/RLS, never touches DB |

### 3.2 Authentication & Identity

| Method | Path | Handler | Auth | Rate limit | Idempotency |
|--------|------|---------|------|------------|-------------|
| POST | `/api/v1/auth/register` | Register | public | ✅ IP+account | — |
| POST | `/api/v1/auth/login` | Login | public | ✅ IP+account | — |
| POST | `/api/v1/auth/refresh` | Refresh | public (refresh token) | ✅ IP | — |
| POST | `/api/v1/auth/logout` | Logout | public (refresh token) | — | — |
| POST | `/api/v1/auth/verify` | Verify (email code) | public | ✅ IP | — |
| GET | `/api/v1/users/me` | Current user | 🔒 Bearer access token | — | — |

### 3.3 Public Discovery (no auth)

| Method | Path | Purpose | Pagination |
|--------|------|---------|-----------|
| GET | `/api/v1/categories` | Seed lookup categories | no (flat list) |
| GET | `/api/v1/venues` | List venues | ✅ |
| GET | `/api/v1/events` | List public events | ✅ |
| GET | `/api/v1/events/{id}` | Event detail | — |

Visibility under these routes is enforced **server/RLS-side** (published /
active / non-deleted). Flutter must not recreate visibility rules as its own
source of truth.

### 3.4 Authenticated Writes

| Method | Path | Handler | Auth | Idempotency |
|--------|------|---------|------|-------------|
| POST | `/api/v1/organizer-applications` | Apply to be organizer | 🔒 | ✅ |
| GET | `/api/v1/organizer-applications/me` | My application status | 🔒 | — |
| POST | `/api/v1/venues` | Create venue | 🔒 | ✅ |
| POST | `/api/v1/events` | Create event (draft) | 🔒 | ✅ |
| PATCH | `/api/v1/events/{id}` | Update event | 🔒 | — |
| POST | `/api/v1/events/{id}/publish` | Publish event | 🔒 | — |

### 3.5 Admin (Next.js admin app, not Flutter)

| Method | Path | Auth |
|--------|------|------|
| POST | `/api/v1/admin/organizer-applications/{id}/approve` | 🔒 admin role |
| POST | `/api/v1/admin/organizer-applications/{id}/reject` | 🔒 admin role |

> These belong to the admin app. Flutter **does not** call them — its concern is
> only the `pending / approved / rejected` state of the applicant's own record.

---

## 4. Data Models (DTOs) Returned to the Frontend

Exact field shapes from `backend/internal/api/dto/*.go`.

### 4.1 AuthResponse (register / login / refresh)

```json
{
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "username": "username",
      "bio": "",
      "photo_url": "",
      "role": "user",
      "is_verified": false,
      "created_at": "RFC3339"
    },
    "access_token": "jwt",
    "refresh_token": "opaque",
    "expires_in_seconds": 900
  }
}
```

- **Default access token lifetime:** 15 minutes.
- **Default refresh token lifetime:** 30 days.
- Registration **asynchronously** queues a welcome email and a 6-digit
  verification email (via outbox; worker delivers; never blocks response).

### 4.2 UserDTO (GET /users/me)

```json
{
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "username": "username",
    "bio": "bio",
    "photo_url": "https://...",
    "role": "user",
    "is_verified": true,
    "created_at": "RFC3339"
  }
}
```

- `role` is `user` or `admin`. **Organizer is NOT a role** — it is a domain
  relationship driven by the organizer-application workflow.

### 4.3 EventDTO (create/update/publish/get/list)

```json
{
  "data": {
    "id": "uuid",
    "organizer_id": "uuid",
    "venue_id": "uuid|null",
    "category_id": "uuid|null",
    "title": "Title",
    "description": "Description",
    "starts_at": "RFC3339",
    "ends_at": "RFC3339|null",
    "price_is_free": true,
    "price_display": "Free",
    "action_type": "rsvp",
    "action_target": "https://...",
    "status": "draft",
    "moderation_status": "clean",
    "max_attendees": 100,
    "created_at": "RFC3339"
  }
}
```

**Event `status` values:** `draft`, `published`, `cancelled`, `completed`,
`archived`.

**`moderation_status` values:** `clean`, `reported`, `blocked`. Independent of
`status` — e.g. `status=published` + `moderation_status=blocked` disappears from
public discovery without changing its event status.

**Clients should disable edit/publish when `status != draft`** but still handle
`409 event_not_draft` because cached state can be stale.

### 4.4 VenueDTO

```json
{
  "data": {
    "id": "uuid",
    "name": "Name",
    "address": "Address",
    "latitude": 0.0,
    "longitude": 0.0,
    "city": "City",
    "country_code": "ET",
    "status": "active"
  }
}
```

### 4.5 CategoryDTO

```json
{ "data": [ { "id": "uuid", "slug": "slug", "name": "Name" } ] }
```

Categories are seeded fixed lookup data; **read-only** for the client. Cache
locally (they change infrequently).

### 4.6 OrganizerApplicationDTO (GET /organizer-applications/me)

```json
{
  "data": {
    "id": "uuid",
    "requested_name": "Name",
    "requested_slug": "slug",
    "bio": "Bio",
    "status": "pending",
    "review_notes": "notes or empty",
    "created_at": "RFC3339"
  }
}
```

**`status` values:** `pending`, `approved`, `rejected`. Only **one pending
application** is allowed — a second returns `409 application_pending`.

---

## 5. Backend Capabilities per Feature Area

### 5.1 Authentication (🟢 LIVE)

- `POST /auth/register` — create account; returns tokens + async welcome/verify emails.
- `POST /auth/login` — returns tokens. Invalid credentials return the same
  `401 invalid_credentials` whether the email doesn't exist or the password is
  wrong — **client must not distinguish** the two.
- `POST /auth/refresh` — **single-use**, **rotating** refresh token. Returns a
  new access + refresh pair.
- `POST /auth/logout` — revokes refresh token; clears server session.
- `GET /users/me` — current profile (auth required).

**Refresh serialization requirement:** Flutter MUST serialize refresh calls.
On a 401 → if a refresh is already running, await it; otherwise start one,
store the new tokens, and retry the original request once. If refresh fails,
log out. Never loop indefinitely.

### 5.2 Email Verification (🟢 LIVE)

- Deep link: `eventnu://verify`
- Flutter extracts the code from the link and calls `POST /auth/verify` with
  `{"code":"123456"}`. There is **no GET** verification endpoint.
- Verify returns `{"data":{"verified":true}}`. After verification the client
  re-fetches `GET /users/me` → `is_verified = true`.
- Do **not** invent a verification response DTO.

### 5.3 Organizer Application (🟢 LIVE)

- Any authenticated user can apply: `POST /organizer-applications`
  ```json
  { "requested_name": "...", "requested_slug": "...", "bio": "..." }
  ```
  Send an `Idempotency-Key`.
- Check status: `GET /organizer-applications/me`.
- Approval/rejection is performed by admins in the **Next.js admin app**
  (Flutter only observes status).

### 5.4 Venues (🟢 LIVE)

- Public listing: `GET /venues` (paginated).
- Organizer creation: `POST /venues` (idempotent) with
  name, address, latitude, longitude, place_id, city, country_code.
- Flutter shows: venue name, address, map preview, location, and a
  **Get Directions** action using lat/long to open the device navigation app.
- Venue misinformation is reported through the report system (planned); Flutter
  confirms submission but must not mark a venue as false itself.

### 5.5 Events (🟢 LIVE)

- Discovery: `GET /events` (paginated), `GET /events/{id}`.
- Organizer: `POST /events`, `PATCH /events/{id}`, `POST /events/{id}/publish`.
- Create/update request body:
  ```json
  {
    "venue_id": "uuid|null",
    "category_id": "uuid|null",
    "title": "...",
    "description": "...",
    "starts_at": "2026-10-01T18:00:00Z",
    "ends_at": "2026-10-01T21:00:00Z",
    "price_is_free": true,
    "price_display": "Free",
    "action_type": "rsvp",
    "action_target": "https://...",
    "max_attendees": 100
  }
  ```
  Dates must be **RFC3339** timestamps (never date-only).
- **Lifecycle:** draft → published; publish is allowed only from `draft`
  (2nd publish → `409 event_not_draft`). Editing/publishing a published event
  is blocked by the backend.

### 5.6 Idempotency (🟢 LIVE)

Supported on client-retryable writes:

- `POST /organizer-applications`
- `POST /venues`
- `POST /events`

The client generates **one UUID v4 per logical submit** and reuses the *same*
key across retries (never a new key for a new retry). The key lives in the
form/state for the duration of that submit-and-retry operation.

---

## 6. Flutter Pages → Backend Capabilities

Maps the planned Flutter screens to the backend capabilities they consume.
**Pages are in the spec but not yet implemented as code.** Endpoint status is
as labelled in §5.

| Screen | Backend capability used | Endpoint(s) | Status |
|--------|------------------------|-------------|--------|
| Splash / Session restore | Auth session | `POST /auth/refresh` | 🟢 |
| Login | Authenticate | `POST /auth/login` | 🟢 |
| Register | Create account | `POST /auth/register` | 🟢 |
| Verify email | Code verification | `POST /auth/verify` + `GET /users/me` | 🟢 |
| Home / Discover | Event + category listing | `GET /events`, `GET /categories` | 🟢 |
| Search / Lists | Paginated lists | `GET /events`, `GET /venues` | 🟢 |
| Event Details | Event detail | `GET /events/{id}` | 🟢 |
| Venue Details / Directions | Venue + coords | `GET /venues` | 🟢 |
| Organizer Application | Apply + status | `POST /organizer-applications`, `GET /organizer-applications/me` | 🟢 |
| Organizer Dashboard / Create Event | Event CRUD + publish | `POST /events`, `PATCH /events/{id}`, `POST /events/{id}/publish` | 🟢 |
| Create Venue | Venue creation | `POST /venues` | 🟢 |
| Profile | Current user | `GET /users/me` | 🟢 |
| Comments | Comment read/write | none yet | 🟡 |
| Social (like / save / follow) | Idempotent social writes | none yet | 🟡 |
| RSVP / Register | Eligibility, capacity | none yet | 🟡 |
| Tickets | Order + ticket issuance | none yet | 🟡 |
| Payments | Order + provider webhook verification | none yet | 🟡 |
| Reviews / Ratings | Eligibility + rating | none yet | 🟡 |
| Reports (event/user/venue) | Report submission | none yet | 🟡 |
| Notifications | Inbox + push + reminders | none yet | 🟡 |
| Media / Gallery | Upload + processing/CDN | none yet | 🟡 |

---

## 7. Error Code Catalog

Known error codes the client should map to typed application exceptions → feature
state → user-friendly UI:

```text
invalid_credentials      (401 login/register)
account_suspended        (auth attempt on suspended account)
email_taken              (register, duplicate email)
username_taken           (register, duplicate username)
bad_request              (malformed/invalid body or params)
unauthorized             (missing/invalid auth)
not_found                (resource or route not found)
too_many_requests        (429 rate limit — see §8)
application_pending      (organizer application already pending)
application_not_pending  (application not in pending state)
event_not_draft          (publish/update on non-draft event)
idempotency_key_reused   (same key, different payload)
idempotency_in_progress  (request with key currently executing)
unavailable              (readyz, DB unreachable)
```

Unknown codes should fall back to a generic error.

---

## 8. Rate Limiting UX

- Auth endpoints are rate-limited (per-IP; per-IP+account for login/register).
  Defaults: login 20/5m, register 5/1h, refresh 30/5m, verify 20/1h.
- A rate-limited response is **`429 too_many_requests`** and includes
  `Retry-After: <seconds>`. Client should use the actual value (countdown /
  retry message) and must **not** auto-retry in a tight loop.

---

## 9. Auth & Session Details

- **Access token:** signed JWT (HS256), default 15 min.
- **Refresh token:** opaque, single-use, rotates on every refresh, default 30 days.
- Sessions are stored server-side (hashed refresh token, user-agent, hashed IP,
  expiry). Logout revokes the session.
- Passwords are bcrypt-hashed (cost 12) with login-timing equalization.

---

## 10. Planned Features — Not Yet in the Backend (🟡)

These are in the target schema (`docs/EVENT_NU_TARGET_SCHEMA_v3.sql`) and the
product spec, but have **no endpoints in the Go API today**. Build order per the
spec: foundation → API client → auth → organizer → venues → events →
comments/social → RSVP → tickets → payments → reviews → reports →
notifications → media → offline reconciliation → hardening → testing → release.

### Planned domain capabilities (all 🟡)
- **Comments** — read/create; backend owns ownership, validation, persistence, moderation.
- **Likes / Saves / Follows** — idempotent, optimistic-friendly.
- **RSVP / Registration** — backend decides eligibility, capacity, event state, duplicates.
- **Tickets** — server-authoritative; backend verifies before issuance.
- **Payments** — authoritative flow: create order → payment provider → webhook → verify → confirm → ticket issued.
- **Reviews / Ratings** — backend determines eligibility and enforces duplicate/validity.
- **Reports** — events, users, venue misinformation; moderation decided server/admin-side.
- **Notifications** — server/worker decides who/why/when; push reminders.
- **Media** — upload authorization → object storage → media record → processing/CDN → optimized assets.
- **Profile editing** — effectively no live update endpoint today (`GET /users/me` is read-only).

### Client rules that apply to planned features
- Offline-capable writes should enter a **local outbox** and reconcile with the
  server; the server is authoritative for financial, inventory, authorization,
  and moderation state.
- Never implement "local data overwrites server" as a universal strategy —
  resolve per feature (likes/saves/follows → idempotent; tickets/payments/moderation → server wins).

---

## 11. First Vertical Slice (recommended starting point)

Per the spec, prove this end-to-end before building every screen:

```
Register → Login → User session → Home → Events → Event details → Venue → Directions
```

Then the organizer path:

```
User → Organizer application → Admin approval → Organizer mode → Create venue
     → Create draft → Edit draft → Publish → User discovers published event
```

---

## 12. Time Handling

- All backend event timestamps are **RFC3339** (timezone-aware).
- Flutter must parse timezone-aware timestamps, preserve the instant, display in
  local timezone, send RFC3339 back, and never send date-only values to
  timestamp fields.
- Example: server `2026-10-01T18:00:00Z` → display `1 Oct · 9:00 PM`.
