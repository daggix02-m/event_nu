
## IMPLEMENTATION ORDER — ONE-PAGE MAP

Follow this dependency order. Do not build all domains in parallel.

```text
0 Architecture contract
 → 1 Repository/tooling foundation
 → 2 Neon/PostgreSQL + roles + RLS
 → 3 Go REST API foundation
 → 4 Authentication + JWT + authorization
 → 5 Users + profiles
 → 6 Flutter offline-first foundation
 → 7 Organizer applications + approval
 → 8 Venues + geolocation
 → 9 Categories
 → 10 Events/posts + lifecycle
 → 11 Flutter discovery + event details
 → 12 Social features
 → 13 RSVP/registration
 → 14 Tickets + orders + payments
 → 15 Reviews/ratings
 → 16 Reports + moderation
 → 17 Notifications + reminders
 → 18 Media + object storage
 → 19 Background worker
 → 20 Complete offline synchronization
 → 21 Next.js Admin foundation
 → 22 Prisma + Admin RLS
 → 23 Admin moderation/management
 → 24 Search/discovery optimization
 → 25 Security hardening
 → 26 Testing + load testing
 → 27 Observability
 → 28 Production deployment
 → 29 Production verification
```

### First major milestone

```text
Register → Login → Profile → Organizer application
→ Admin approval → Create event → Publish
→ Flutter discovery → Event details → Real venue → Navigation
```

### Vertical-slice rule

For each feature: `Database → Domain → Repository → Service → Authorization/RLS → Handler → REST endpoint → API tests → Flutter/Admin repository → UI → Offline behavior → integration/E2E tests`.



# 0A. Pre-Implementation Review Corrections — v2.2 (implemented)

C1–C6 below are no longer aspirational: they are implemented directly in
`EVENT_NU_TARGET_SCHEMA.sql`. C7 and C8 are process/design notes, not schema
changes. Anyone extending the schema should treat the SQL file, not this
prose, as the source of truth if the two ever drift — but as of this
revision they match.

## C1 — Stories use the canonical media pipeline (implemented)

`stories.media_asset_id uuid NOT NULL REFERENCES media_assets(id)` replaces the old `media_url`/`media_type` columns. Story media goes through the same R2 → processing → variants → CDN pipeline as every other media kind (`media_kind` already included `'story'`).

## C2 — Ticket inventory is concurrency-safe (implemented)

`ticket_types` now carries `CONSTRAINT ticket_types_sold_le_total_chk CHECK (quantity_total IS NULL OR quantity_sold <= quantity_total)` as the defensive backstop. The actual reservation is atomic: the Go checkout service calls the `reserve_ticket_inventory(p_ticket_type_id, p_quantity)` SQL function inside the order transaction, which performs the conditional `UPDATE ... WHERE ... AND (quantity_total IS NULL OR quantity_sold + :quantity <= quantity_total) RETURNING true` and returns `false` (reserving nothing) when inventory isn't available. A matching `release_ticket_inventory(p_ticket_type_id, p_quantity)` function exists for cancellations/refunds prior to ticket use. Application code must never issue a raw `UPDATE` against `quantity_sold` directly. Retries reuse the same idempotency key.

## C3 — Currency consistency is explicit (implemented)

`order_items` gained a `currency char(3) NOT NULL` column. Two `BEFORE INSERT OR UPDATE` triggers — `enforce_order_item_currency()` on `order_items` and `enforce_payment_currency()` on `payments` — raise an exception if a row's currency doesn't match its parent `orders.currency` (and, for `order_items`, its `ticket_types.currency`). This is the database backstop; the Go service must still validate the same invariant before commit.

```text
ticket_type.currency = order_item.currency = order.currency = payment.currency
```

## C4 — RLS is implemented, not aspirational (implemented)

`EVENT_NU_TARGET_SCHEMA.sql` now contains: three roles (`app_user`, `worker_role`, `admin_dashboard`, created idempotently via a guarded `DO` block), four context helper functions (`current_app_user_id()`, `current_app_role()`, `current_app_organizer_id()`, plus `is_admin()` and `is_privileged()` — the latter covers both the admin role and the worker's trusted internal `service` context), `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` on every table, and table-appropriate `CREATE POLICY` + `GRANT` statements — roughly 85 policies in total, following the policy matrix in §10.4.

Application context is transaction-local:

```sql
SELECT set_config('app.user_id', :user_id, true);
SELECT set_config('app.role', :role, true);
SELECT set_config('app.organizer_id', :organizer_id, true);
```

`true` means `is_local`, so pooled connections cannot retain request context after commit/rollback.

Go remains the primary authorization/business layer; RLS is the database backstop. The Admin app verifies the Go JWT and then uses Prisma inside a transaction that sets `app.role = 'admin'`.

Two design notes surfaced while writing the actual policies (not present in the original matrix, added for correctness — see C8) and one deliberate limitation carried over from the matrix as written:

- Tables holding "own rows only" data for social features (`likes`, `saves`, `organizer_follows`, `story_views`) cannot serve an aggregate count (like/follower/view totals) through a plain `COUNT(*)` run as `app_user` — RLS would only count the requester's own row. Aggregate counts need a maintained counter column, a materialized view, or a `SECURITY DEFINER` function; this is flagged inline in the schema and is an open implementation decision, not yet resolved.
- `event_rsvps` deliberately has no organizer-facing `SELECT` policy. Per the matrix, an organizer's visibility into RSVPs for their own events is "read through controlled Go operations," so that read path belongs in a `SECURITY DEFINER` function/service query, not a raw RLS policy — keeping it auditable and separate from ordinary row access.

## C5 — HNSW configuration is deliberate (implemented)

`events_embedding_idx` is now `USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64)`. Benchmark and tune before production based on corpus size, build time, recall, and query latency. Query-time `hnsw.ef_search` is a separate, per-session GUC and is not set in the schema. The embedding dimension and model are configuration decisions and must not change without a migration/re-index plan.

## C6 — Magic-link purpose is typed (implemented)

`magic_link_tokens.purpose` is now `magic_link_purpose NOT NULL`, a new enum with values `login`, `verify`, `reset_password`, rather than free-form text.

## C7 — Scope is staged

The schema describes the full platform, but implementation is phased. Do not build every table at once. The dependency-ordered implementation plan below is authoritative. MVP work stops after the core discovery/organizer/event path and then expands feature-by-feature.

## C8 — Processed media and published-event galleries must be publicly readable

Found while writing the C4 policies, not in the original matrix: a strict "owner or admin only" `SELECT` policy on `media_assets`/`media_variants` and an organizer-only policy on `event_gallery_items` would have made it impossible for any non-owner — including an anonymous browsing user — to ever see a published event's poster or gallery images, breaking core discovery. The schema now adds a public-read policy for `media_assets`/`media_variants` once `status = 'ready'`, and a separate public-read policy on `event_gallery_items` scoped to `events.status = 'published' AND moderation_status != 'blocked' AND deleted_at IS NULL`, alongside the existing owner/organizer management policies. Un-processed media (pending/processing/failed) stays owner+admin-only; a draft event's still-processing poster is protected by that processing-status window, not by the event's publish status, which this table does not track — Go's own event-visibility check remains the primary control for "should this be shown yet."
# Event Nu — Complete Product, Architecture, Database & Implementation Documentation

**Status:** Architecture / implementation specification
**Date:** 2026-09-01
**Scope:** Documentation only — this document does not modify the existing project.

---

## 0. Purpose

This document is the single implementation reference for Event Nu. It defines:

- product actors and responsibilities;
- Flutter application workflow;
- Next.js admin workflow;
- Go REST API architecture;
- Neon PostgreSQL architecture;
- PostgreSQL RLS model;
- complete target database schema;
- entities, attributes, relationships and indexes;
- authentication and authorization;
- organizer approval;
- event publishing and moderation;
- venue/location handling;
- comments, likes, saves, follows and sharing;
- RSVP and ticket purchasing;
- reviews and ratings;
- reporting and moderation;
- notifications and reminders;
- media storage and processing;
- offline-first synchronization;
- background workers;
- REST API conventions;
- admin/Prisma access boundaries;
- implementation phases;
- testing, security, deployment and operations;
- acceptance criteria for production readiness.

The existing repository is a **scaffold**, not the completed application. Existing code and migrations are therefore distinguished from the **target architecture** in this document.

---

# 1. Product Definition

Event Nu is an event discovery and participation platform with two client applications:

1. **Flutter mobile application** — used by regular users and organizers.
2. **Next.js admin application** — used only by administrators.

There is no regular-user web application.

The platform is backed by one Go REST API, one Neon PostgreSQL database, and a Go background worker.

## 1.1 High-level architecture

```text
                         EVENT NU
                            |
              +-------------+-------------+
              |                           |
              v                           v
       +-------------+             +---------------+
       | Flutter App |             | Next.js Admin |
       | Users       |             | Admins        |
       | Organizers  |             +-------+-------+
       +------+------+                     |
              |                            |
              | REST/JSON                  | Prisma / REST
              v                            v
       +------------------------------------------+
       |                Go Backend                |
       |                                            |
       | REST API | Auth | Services | RLS context |
       +--------------------+---------------------+
                            |
                            v
                   +-------------------+
                   | Neon PostgreSQL    |
                   | Source of truth    |
                   +-------------------+
                            ^
                            |
                   +-------------------+
                   | Go Worker          |
                   | media/jobs/etc.    |
                   +-------------------+

Object media:
Flutter/Admin -> Go-issued presigned URL -> Cloudflare R2 -> CDN
```

## 1.2 Core technology decisions

| Layer | Technology | Responsibility |
|---|---|---|
| User client | Flutter | Mobile UI, local database, offline-first behavior |
| Admin client | Next.js | Admin dashboard |
| API | Go `net/http` | REST API, authentication, authorization, business logic |
| Database | Neon PostgreSQL | Source of truth |
| DB driver | pgx | Go/Postgres access |
| Migrations | Goose | Versioned schema changes |
| Admin DB client | Prisma | Selected admin queries/mutations |
| DB authorization | PostgreSQL RLS | Database-level defense in depth |
| Auth | Custom Go JWT | One authentication system for all clients |
| Password hashing | bcrypt | Password storage |
| Object storage | Cloudflare R2 | Images/media |
| Image processing | libvips/bimg | Background media transformations |
| Search | PostgreSQL FTS + pgvector | Keyword + semantic search |
| Background jobs | Go worker + PostgreSQL | Durable asynchronous processing |
| Scheduling | pg_cron where available | Maintenance/scheduled jobs |

Cloudflare R2 is the preferred media provider because its current Standard storage free tier includes 10 GB-month, 1 million Class A operations, 10 million Class B operations per month, and free internet egress. Verify the current limits before production deployment. citeturn0search0turn0search1

Neon remains the PostgreSQL provider. Verify the specific Neon project/plan before making logical replication or pg_cron a hard dependency.

---

# 2. Actors and Authorization Model

There are exactly two application roles:

```text
user
admin
```

## 2.1 Regular user

A regular user can:

- register and log in;
- manage their profile;
- discover events;
- search and filter events;
- view event details;
- navigate to event venues;
- like events;
- save events into folders;
- comment on events;
- share events;
- follow organizers;
- RSVP/register for events;
- purchase tickets;
- receive notifications and event reminders;
- review/rate events after the appropriate participation condition;
- report events;
- report users;
- report venues for misinformation;
- apply to become an organizer.

## 2.2 Organizer

Organizer is **not** a value of `users.role`.

An organizer is a separate domain entity owned by a user:

```text
users
  |
  | owner_user_id
  v
organizers
```

A user becomes an organizer only after an organizer application is approved by an admin.

An approved organizer can:

- manage its organizer profile;
- create event posts;
- edit its own events;
- publish events;
- manage event media;
- manage its own venues where permitted;
- view RSVP/ticket information for its own events;
- manage organizer-facing content.

An organizer remains subject to admin moderation.

## 2.3 Admin

Admins use only the Next.js admin application.

Admin capabilities include:

- manage users;
- moderate users/reports;
- review organizer applications;
- approve/reject/suspend organizers;
- moderate events;
- block/restore events;
- manage venues;
- review venue misinformation reports;
- manage categories;
- manage media metadata/processing;
- manage announcements;
- manage CMS pages;
- inspect notifications/jobs;
- inspect audit logs;
- perform administrative actions through Go when business side effects are involved.

## 2.4 Role vs ownership

Never introduce `organizer` into `users.role` merely because a user owns an organizer record.

Correct:

```text
users.role = 'user'
users -> organizers -> events
```

Incorrect:

```text
users.role = 'organizer'
```

This keeps identity/authorization separate from domain ownership.

---

# 3. Complete Application Workflow

## 3.1 Registration

```text
Flutter
  -> POST /api/v1/auth/register
  -> Go handler
  -> Auth/User service
  -> validate input
  -> hash password
  -> create users row
  -> issue JWT/session
  -> return authenticated user
```

## 3.2 Login

```text
Flutter or Next.js Admin
  -> POST /api/v1/auth/login
  -> Go authentication service
  -> lookup user
  -> bcrypt verification
  -> load role
  -> issue JWT containing role
  -> client stores session securely
```

The same endpoint is used for users and admins.

Admin login is not a second authentication system.

## 3.3 JWT

Target claims:

```json
{
  "sub": "user-uuid",
  "role": "user",
  "iat": 1760000000,
  "exp": 1760003600,
  "jti": "session-uuid"
}
```

The minimum required addition to the current scaffold is `role` in `authdomain.Claims`.

Recommended production addition: short-lived access tokens plus refresh/session tokens.

## 3.4 Event discovery

```text
Flutter
  |
  +--> local SQLite
  |      |
  |      +--> cached published events
  |      +--> categories
  |      +--> venues
  |
  +--> Go REST API for writes and server operations
```

Offline-first reads should remain available when the network is unavailable.

## 3.5 Event post workflow

```text
Approved Organizer
      |
      v
Create event draft
      |
      +--> title
      +--> description
      +--> venue
      +--> category
      +--> dates
      +--> pricing
      +--> action/ticket configuration
      +--> media
      |
      v
Publish
      |
      v
Published event
      |
      +--> discoverable
      +--> searchable
      +--> shareable
      +--> reportable
      |
      v
User report (optional)
      |
      v
Admin review
      |
      +--> keep published
      +--> restore
      +--> block
      +--> cancel
      +--> archive
```

The event is fundamentally a post. User reporting does not automatically mean the post is blocked; reports create a moderation case.

## 3.6 Organizer application

```text
User
  -> organizer application
  -> pending
  -> Admin review
      +--> rejected
      +--> approved
      +--> needs_more_information
  -> organizer entity created/activated
```

## 3.7 Venue workflow

A venue represents an actual physical location.

```text
Venue
  +-- name
  +-- address
  +-- latitude
  +-- longitude
  +-- optional place metadata
```

Flutter can use latitude/longitude to open the device's map/navigation application.

Venue misinformation is independently reportable:

```text
User -> Report Venue -> Admin -> review -> correct/disable/restore
```

## 3.8 RSVP workflow

```text
User
  -> RSVP
  -> Go service
  -> validate event availability
  -> enforce capacity/eligibility
  -> create RSVP
  -> notification/reminder scheduling
```

The RSVP operation must be idempotent.

## 3.9 Ticket workflow

```text
User
  -> select ticket type
  -> create checkout/order
  -> payment provider
  -> payment confirmation
  -> order paid
  -> ticket issued
  -> QR/code generated
```

Payment-provider implementation is deliberately provider-neutral until a provider is selected.

Never mark an order as paid solely because the Flutter client says payment succeeded. Payment confirmation must be verified server-side.

## 3.10 Review workflow

```text
User attends/completes event
  -> review eligibility
  -> rating 1..5
  -> optional text
  -> review
```

A recommended rule is one review per user per event.

## 3.11 Reporting workflow

```text
User
  -> report event/user/venue/comment
  -> report stored
  -> moderation queue
  -> admin reviews
  -> admin action
  -> audit log
```

Reporting must not automatically delete content.

## 3.12 Notification/reminder workflow

```text
Event / RSVP / Follow / Moderation action
  -> notification service
  -> notifications table
  -> Flutter sync/push layer

Event reminder:
  event_reminders
      -> worker/scheduler
      -> notification
```

Push delivery provider should be isolated behind a notification interface.

---

# 4. REST API Architecture

The Go application owns the REST API.

```text
HTTP request
    |
    v
Router
    |
    v
Middleware
    +-- recovery
    +-- request ID
    +-- logging
    +-- CORS
    +-- authentication
    +-- authorization
    +-- request timeout
    |
    v
Handler
    |
    v
Service/use case
    |
    v
Repository
    |
    v
Neon PostgreSQL
```

## 4.1 Handler responsibility

Handlers should:

- parse HTTP input;
- validate transport-level input;
- obtain authenticated identity;
- call the service;
- map application errors to HTTP responses;
- serialize JSON.

Handlers should not contain SQL or complex business rules.

## 4.2 Service responsibility

Services implement use cases:

- authorization decisions;
- state transitions;
- transaction boundaries;
- business invariants;
- idempotency;
- side effects;
- domain validation.

## 4.3 Repository responsibility

Repositories own database queries and persistence mapping.

## 4.4 API versioning

All public endpoints use:

```text
/api/v1/...
```

## 4.5 API response convention

Success:

```json
{
  "data": {}
}
```

Paginated:

```json
{
  "data": [],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "has_next": true
  }
}
```

Error:

```json
{
  "error": {
    "code": "event_blocked",
    "message": "This event is not available."
  }
}
```

Never expose SQL errors, stack traces, credentials, or internal infrastructure details.

---

# 5. API Endpoint Map

This is the target API surface. It is a specification, not a statement that all endpoints currently exist in the scaffold.

## Authentication

```text
POST   /api/v1/auth/register
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
POST   /api/v1/auth/logout
POST   /api/v1/auth/verify
POST   /api/v1/auth/password/reset/request
POST   /api/v1/auth/password/reset/confirm
```

## Users

```text
GET    /api/v1/users/me
PATCH  /api/v1/users/me
DELETE /api/v1/users/me
GET    /api/v1/users/:id
```

## Organizers

```text
POST   /api/v1/organizer-applications
GET    /api/v1/organizer-applications/me
POST   /api/v1/organizers
GET    /api/v1/organizers/:id
PATCH  /api/v1/organizers/:id
GET    /api/v1/organizers/:id/events
```

Creation of an organizer is only allowed after approval.

## Venues

```text
GET    /api/v1/venues
GET    /api/v1/venues/:id
POST   /api/v1/venues
PATCH  /api/v1/venues/:id
POST   /api/v1/venues/:id/reports
```

## Categories

```text
GET    /api/v1/categories
GET    /api/v1/categories/:id
```

## Events

```text
GET    /api/v1/events
GET    /api/v1/events/:id
POST   /api/v1/events
PATCH  /api/v1/events/:id
DELETE /api/v1/events/:id
POST   /api/v1/events/:id/publish
POST   /api/v1/events/:id/cancel
```

## Comments

```text
GET    /api/v1/events/:id/comments
POST   /api/v1/events/:id/comments
PATCH  /api/v1/comments/:id
DELETE /api/v1/comments/:id
POST   /api/v1/comments/:id/report
```

## Social

```text
POST   /api/v1/events/:id/like
DELETE /api/v1/events/:id/like
POST   /api/v1/events/:id/save
DELETE /api/v1/events/:id/save
POST   /api/v1/events/:id/share
GET    /api/v1/me/saves
POST   /api/v1/organizers/:id/follow
DELETE /api/v1/organizers/:id/follow
```

## RSVP

```text
POST   /api/v1/events/:id/rsvp
DELETE /api/v1/events/:id/rsvp
GET    /api/v1/events/:id/rsvp
GET    /api/v1/me/rsvps
```

## Tickets

```text
GET    /api/v1/events/:id/ticket-types
POST   /api/v1/events/:id/orders
GET    /api/v1/orders/:id
POST   /api/v1/orders/:id/cancel
GET    /api/v1/me/orders
GET    /api/v1/me/tickets
```

Payment webhook:

```text
POST   /api/v1/webhooks/payments/:provider
```

## Reviews

```text
GET    /api/v1/events/:id/reviews
POST   /api/v1/events/:id/reviews
PATCH  /api/v1/reviews/:id
DELETE /api/v1/reviews/:id
```

## Reports

```text
POST /api/v1/events/:id/reports
POST /api/v1/users/:id/reports
POST /api/v1/venues/:id/reports
POST /api/v1/comments/:id/reports
```

## Notifications

```text
GET    /api/v1/notifications
POST   /api/v1/notifications/:id/read
POST   /api/v1/notifications/read-all
```

## Media

```text
POST   /api/v1/media/upload-intents
POST   /api/v1/media/:id/complete
GET    /api/v1/media/:id
DELETE /api/v1/media/:id
```

## Admin business actions

```text
GET    /api/v1/admin/reports
POST   /api/v1/admin/reports/:id/resolve
POST   /api/v1/admin/events/:id/block
POST   /api/v1/admin/events/:id/restore
POST   /api/v1/admin/organizer-applications/:id/approve
POST   /api/v1/admin/organizer-applications/:id/reject
POST   /api/v1/admin/users/:id/suspend
POST   /api/v1/admin/users/:id/restore
POST   /api/v1/admin/venues/:id/disable
POST   /api/v1/admin/venues/:id/restore
```

These admin business actions stay in Go because they can trigger side effects and audit events.

---

# 6. Target Database Architecture

Neon PostgreSQL is the system of record.

## 6.1 Database extensions

Target extensions:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
```

`pg_cron` is optional and must only be enabled after confirming Neon support for the project/plan.

## 6.2 Database principles

- UUID primary keys.
- `timestamptz` for timestamps.
- UTC at the database layer.
- Foreign keys for integrity.
- Explicit `ON DELETE` behavior.
- Soft deletion where historical references matter.
- Unique constraints for idempotent relationships.
- Partial indexes for active/public records.
- Full-text search using `tsvector`.
- Optional semantic search using `vector`.
- Media bytes never stored in PostgreSQL.
- Business-critical mutations are transactional.

---

# 7. Complete Target Entity Model

The target model contains the following major entities:

```text
User
 |
 +-- OrganizerApplication
 |
 +-- Organizer
 |      |
 |      +-- Venue
 |      +-- Event
 |             |
 |             +-- Media
 |             +-- Comment
 |             +-- Like
 |             +-- Save
 |             +-- Share
 |             +-- RSVP
 |             +-- TicketType
 |             +-- Order/Ticket
 |             +-- Review
 |             +-- Report
 |             +-- Reminder
 |
 +-- Follow
 +-- Notification
 +-- Report
 +-- Review
 +-- Comment
 +-- MediaAsset
 |
 +-- Session
 +-- IdempotencyKey
 +-- Sync metadata
```

Admin actions are recorded in `audit_logs`.

---

# 8. Full Target Database Schema

The following is the target logical schema. It expands the current scaffold to cover the confirmed product requirements.

## 8.1 Users

### `users`

| Column | Type | Null | Default | Purpose |
|---|---|---:|---|---|
| id | uuid | no | gen_random_uuid() | User ID |
| email | text | no | | Unique login identifier |
| password_hash | text | yes | | bcrypt hash |
| username | text | yes | | Public username |
| bio | text | yes | | Profile biography |
| photo_url | text | yes | | Legacy/simple profile URL; preferably media reference later |
| role | user_role | no | `user` | `user` or `admin` |
| is_verified | boolean | no | false | Email/account verification |
| privacy | jsonb | no | `{}` | User privacy settings |
| status | user_status | no | `active` | Active/suspended/deactivated |
| created_at | timestamptz | no | now() | Creation time |
| updated_at | timestamptz | no | now() | Last update |
| deleted_at | timestamptz | yes | | Soft deletion |

Enums:

```sql
CREATE TYPE user_role AS ENUM ('user', 'admin');
CREATE TYPE user_status AS ENUM ('active', 'suspended', 'deactivated');
```

Constraints:

```text
users.email UNIQUE
users.username UNIQUE where username is not null
```

## 8.2 Authentication

### `magic_link_tokens`

```text
 token_hash     text PK
 user_id        uuid FK users
 purpose        text
 expires_at     timestamptz
 used_at        timestamptz NULL
```

### `auth_sessions`

Recommended production table:

```text
id              uuid PK
user_id         uuid FK users
refresh_hash    text UNIQUE
user_agent      text NULL
ip_hash         text NULL
device_name     text NULL
expires_at      timestamptz
revoked_at      timestamptz NULL
created_at      timestamptz
updated_at      timestamptz
```

Refresh tokens are stored as hashes, never plaintext.

## 8.3 Organizer applications

### `organizer_applications`

```text
id                  uuid PK
user_id             uuid FK users
requested_name      text
requested_slug      text NULL
bio                 text NULL
supporting_data     jsonb
status              organizer_application_status
reviewed_by        uuid FK users NULL
reviewed_at         timestamptz NULL
review_notes        text NULL
created_at          timestamptz
updated_at          timestamptz
```

Enum:

```text
pending
approved
rejected
needs_more_information
withdrawn
```

Only admins can transition an application to `approved` or `rejected`.

## 8.4 Organizers

### `organizers`

```text
id              uuid PK
owner_user_id   uuid FK users NULL
slug            text UNIQUE
name            text
bio             text NULL
logo_media_id   uuid FK media_assets NULL
profile         jsonb
status          organizer_status
created_at      timestamptz
updated_at      timestamptz
deleted_at      timestamptz NULL
```

Enum:

```text
active
suspended
archived
```

## 8.5 Venues

### `venues`

```text
id                  uuid PK
organizer_id        uuid FK organizers NULL
name                text
address             text NULL
latitude            double precision
longitude           double precision
place_id            text NULL
city                text NULL
country_code        text NULL
metadata            jsonb
status              venue_status
created_at          timestamptz
updated_at          timestamptz
deleted_at          timestamptz NULL
```

Enum:

```text
active
under_review
disabled
archived
```

`latitude` and `longitude` are required for a published event venue unless the event is explicitly configured as an online/remote event.

## 8.6 Categories

### `categories`

```text
id          uuid PK
slug        text UNIQUE
name        text
sort_order  integer
is_active   boolean
created_at  timestamptz
updated_at  timestamptz
```

## 8.7 Media

### `media_assets`

```text
id              uuid PK
uploader_id     uuid FK users
kind            media_kind
storage_bucket  text
storage_key     text
content_type    text
byte_size       bigint
width           integer
height          integer
blurhash        text NULL
status          media_status
error_message   text NULL
created_at      timestamptz
updated_at      timestamptz
```

### `media_variants`

```text
id               uuid PK
media_asset_id   uuid FK media_assets
variant          text
 density         text
format           text
width            integer
height           integer
storage_key      text
cdn_url          text
byte_size        bigint NULL
created_at       timestamptz
```

Unique:

```text
(media_asset_id, variant, density, format)
```

### `media_processing_jobs`

```text
id              uuid PK
media_asset_id  uuid FK media_assets
status          text
attempts        integer
last_error      text NULL
created_at      timestamptz
updated_at      timestamptz
```

## 8.8 Events

### `events`

```text
id                  uuid PK
organizer_id        uuid FK organizers
venue_id            uuid FK venues NULL
category_id         uuid FK categories NULL
title               text
description         text NULL
poster_media_id     uuid FK media_assets NULL
teaser_media_id     uuid FK media_assets NULL
starts_at           timestamptz
ends_at             timestamptz NULL
price_is_free       boolean
price_display       text NULL
action_type         event_action_type
action_target       text NULL
status              event_status
moderation_status   moderation_status
featured            featured_section NULL
max_attendees       integer NULL
search_vector       tsvector GENERATED
embedding           vector(1536) NULL
created_at          timestamptz
updated_at          timestamptz
deleted_at          timestamptz NULL
```

Recommended event statuses:

```text
draft
published
cancelled
completed
archived
```

Moderation status:

```text
clean
reported
under_review
blocked
restored
```

Do not encode a user report as a permanent event status. Reports are separate records.

### `event_gallery_items`

```text
event_id        uuid FK events
media_asset_id  uuid FK media_assets
sort_order      integer
PRIMARY KEY(event_id, media_asset_id)
```

## 8.9 Comments

### `comments`

```text
id              uuid PK
event_id        uuid FK events
user_id         uuid FK users
parent_id       uuid FK comments NULL
body            text
status          comment_status
created_at      timestamptz
updated_at      timestamptz
deleted_at      timestamptz NULL
```

Enum:

```text
visible
hidden
blocked
deleted
```

`parent_id` supports replies if replies are enabled.

## 8.10 Likes

### `likes`

```text
user_id       uuid FK users
event_id      uuid FK events
created_at    timestamptz
PRIMARY KEY(user_id, event_id)
```

## 8.11 Save folders

### `save_folders`

```text
id          uuid PK
user_id     uuid FK users
name        text
created_at  timestamptz
updated_at  timestamptz
```

### `saves`

```text
user_id     uuid FK users
event_id    uuid FK events
folder_id   uuid FK save_folders NULL
created_at  timestamptz
PRIMARY KEY(user_id, event_id)
```

## 8.12 Shares

### `shares`

```text
id          uuid PK
user_id     uuid FK users NULL
event_id    uuid FK events
channel     text NULL
created_at  timestamptz
```

Anonymous shares may be permitted if product analytics require it.

## 8.13 Organizer follows

### `organizer_follows`

```text
user_id        uuid FK users
organizer_id   uuid FK organizers
created_at     timestamptz
PRIMARY KEY(user_id, organizer_id)
```

## 8.14 RSVP

### `event_rsvps`

```text
id              uuid PK
event_id        uuid FK events
user_id         uuid FK users
status          rsvp_status
quantity        integer
created_at      timestamptz
updated_at      timestamptz
cancelled_at    timestamptz NULL
```

Enum:

```text
confirmed
waitlisted
cancelled
attended
no_show
```

Unique recommended:

```text
(user_id, event_id)
```

If multiple registrations per user are later required, use a registration/order model instead.

## 8.15 Ticket types

### `ticket_types`

```text
id              uuid PK
event_id        uuid FK events
name            text
description     text NULL
price_minor     bigint
currency        char(3)
quantity_total  integer NULL
quantity_sold   integer
sales_start     timestamptz NULL
sales_end       timestamptz NULL
is_active       boolean
created_at      timestamptz
updated_at      timestamptz
```

Money is stored in the smallest currency unit, never floating point.

### Ticket inventory invariant

For limited inventory:

```text
quantity_sold <= quantity_total
```

The database has a defensive check constraint, but checkout must reserve inventory atomically. Use the `reserve_ticket_inventory(ticket_type_id, quantity)` database function (or the equivalent single conditional `UPDATE`) inside the order transaction. If it returns false, the requested inventory is unavailable. Retries must reuse the same idempotency key.

### Currency invariant

For an order, the currency must remain consistent:

```text
ticket_type.currency = order_item.currency = order.currency = payment.currency
```

Cross-table triggers enforce this at the database boundary and Go validates it before commit.

## 8.16 Orders

### `orders`

```text
id                uuid PK
user_id           uuid FK users
event_id          uuid FK events
status            order_status
currency          char(3)
subtotal_minor    bigint
total_minor       bigint
payment_provider  text NULL
provider_ref      text NULL
created_at        timestamptz
updated_at        timestamptz
paid_at           timestamptz NULL
cancelled_at      timestamptz NULL
```

## 8.17 Order items

### `order_items`

```text
id              uuid PK
order_id        uuid FK orders
ticket_type_id  uuid FK ticket_types
quantity        integer
currency        char(3)
unit_price      bigint
subtotal        bigint
created_at      timestamptz
```

## 8.18 Tickets

### `tickets`

```text
id              uuid PK
order_item_id   uuid FK order_items
user_id         uuid FK users
event_id        uuid FK events
ticket_type_id  uuid FK ticket_types
code_hash       text UNIQUE
status          ticket_status
issued_at       timestamptz
used_at         timestamptz NULL
created_at      timestamptz
```

Ticket codes should be represented securely; do not store a reusable bearer code in plaintext if the code itself grants entry.

## 8.19 Payments

### `payments`

```text
id                uuid PK
order_id          uuid FK orders
provider          text
provider_payment_id text
status            payment_status
amount_minor      bigint
currency          char(3)
raw_reference     jsonb NULL
created_at        timestamptz
updated_at        timestamptz
paid_at           timestamptz NULL
failed_at         timestamptz NULL
```

Never trust client-side payment state. Provider webhooks must be verified.

## 8.20 Reviews

### `reviews`

```text
id              uuid PK
event_id        uuid FK events
user_id         uuid FK users
rating          smallint
body            text NULL
status          review_status
created_at      timestamptz
updated_at      timestamptz
deleted_at      timestamptz NULL
```

Constraint:

```text
rating BETWEEN 1 AND 5
```

Recommended unique constraint:

```text
(user_id, event_id)
```

## 8.21 Reports

### `reports`

This is a polymorphic moderation table.

```text
id                uuid PK
reporter_user_id  uuid FK users
entity_type       report_entity_type
entity_id         uuid
reason_code       text
description       text NULL
status            report_status
assigned_to       uuid FK users NULL
resolution        text NULL
created_at        timestamptz
updated_at        timestamptz
resolved_at       timestamptz NULL
```

`entity_type` values:

```text
event
user
venue
comment
organizer
```

Because PostgreSQL cannot enforce a conventional foreign key against different tables from `entity_id`, the application service and moderation workflow must enforce target validity. If stronger database integrity is required, separate report tables can be introduced later.

## 8.22 Notifications

### `notifications`

```text
id              uuid PK
user_id         uuid FK users
type            notification_type
title           text
body            text
data            jsonb
read_at         timestamptz NULL
created_at      timestamptz
```

`data` contains IDs and routing metadata, not sensitive secrets.

## 8.23 Event reminders

### `event_reminders`

```text
id              uuid PK
event_id        uuid FK events
user_id         uuid FK users
remind_at       timestamptz
status          reminder_status
notification_id uuid FK notifications NULL
created_at      timestamptz
sent_at         timestamptz NULL
```

Unique recommendation:

```text
(user_id, event_id, remind_at)
```

## 8.24 Push devices

### `user_devices`

```text
id              uuid PK
user_id         uuid FK users
platform        device_platform
push_token      text
device_name     text NULL
last_seen_at    timestamptz
created_at      timestamptz
revoked_at      timestamptz NULL
```

## 8.25 Stories

### `stories`

```text
id              uuid PK
user_id         uuid FK users
media_asset_id  uuid FK media_assets
category        text NULL
created_at      timestamptz
expires_at      timestamptz
```

### `story_views`

```text
story_id     uuid FK stories
viewer_id    uuid FK users
viewed_at    timestamptz
PRIMARY KEY(story_id, viewer_id)
```

Use an unlogged table only if losing view analytics is explicitly acceptable.

## 8.26 Announcements

### `announcements`

```text
id          uuid PK
message     text
is_active   boolean
starts_at   timestamptz NULL
ends_at     timestamptz NULL
created_at  timestamptz
updated_at  timestamptz
```

## 8.27 CMS pages

### `pages`

```text
slug        text PK
content     jsonb
updated_at  timestamptz
updated_by  uuid FK users NULL
```

## 8.28 Rate limits

### `rate_limits`

```text
key          text PK
count        integer
window_start timestamptz
```

This may remain unlogged if rate-limit state is disposable.

## 8.29 Idempotency

### `idempotency_keys`

Required for offline-first mutations.

```text
id              uuid PK
user_id         uuid FK users
key             text
request_hash    text
operation       text
status          idempotency_status
response_code   integer NULL
response_body   jsonb NULL
created_at      timestamptz
expires_at      timestamptz
```

Unique:

```text
(user_id, key)
```

This prevents an offline retry from creating duplicate RSVP/orders/comments/etc.

## 8.30 Audit logs

### `audit_logs`

```text
id              uuid PK
actor_user_id   uuid FK users NULL
action          text
entity_type     text
entity_id       uuid NULL
metadata        jsonb
created_at      timestamptz
```

Admin actions must be auditable.

---

# 9. Entity Relationships

```text
users
 |
 +--------------------------+
 |                          |
 v                          v
organizer_applications     organizers
                              |
                    +---------+---------+
                    |                   |
                    v                   v
                  venues              events
                                        |
          +-------------+--------------+--------------+
          |             |              |              |
          v             v              v              v
       comments       likes          saves          shares
          |
          v
       reports

users -> organizer_follows -> organizers
users -> event_rsvps -> events
users -> reviews -> events
users -> orders -> events
orders -> order_items -> ticket_types -> events
order_items -> tickets
users -> notifications
users -> event_reminders -> events
users -> reports
users -> media_assets -> media_variants
media_assets -> media_processing_jobs
users -> user_devices
users -> auth_sessions
users -> audit_logs
```

---

# 10. RLS Architecture

RLS should be used as a database defense-in-depth layer, not as a replacement for application authorization.

## 10.1 Database roles

Recommended logical database roles:

```text
neon_owner / migration role
        |
        +-- schema management only

app_user
        |
        +-- Go API

worker_role
        |
        +-- Go worker

admin_dashboard
        |
        +-- Next.js Prisma
```

Exact Neon role setup depends on how the project manages privileged roles.

## 10.2 Why Go should not simply bypass RLS

The Go API is the main application path. If it always connects as the table owner, RLS cannot protect that path.

Target design:

```text
JWT
  |
  v
Go authorization
  |
  v
transaction
  |
  +-- SET LOCAL app.user_id
  +-- SET LOCAL app.role
  +-- SET LOCAL app.organizer_id (when applicable)
  |
  v
PostgreSQL RLS
```

## 10.3 RLS context

Example:

```sql
SELECT set_config('app.user_id', $1, true);
SELECT set_config('app.role', $2, true);
SELECT set_config('app.organizer_id', $3, true);
```

The third argument `true` makes the setting transaction-local.

This is important with pooled connections: authorization context must not leak between requests.

## 10.4 Concrete RLS policy model

The target SQL schema contains actual policies, not only examples. The policy matrix is:

| Table/domain | Regular user | Organizer owner | Admin |
|---|---|---|---|
| `users` | own row | own user row | all |
| `organizer_applications` | own application | own application | all |
| `organizers` | own organizer | own organizer | all |
| `venues` | active public read | owned organizer CRUD | all |
| `events` | published/visible read | owned organizer create/update | all |
| `comments` | visible read + own CRUD | same user rules | all |
| `likes` / `saves` / `follows` | own rows | own rows | admin where required |
| `event_rsvps` | own rows | read through controlled Go operations | admin where required |
| `reviews` | eligible user's own row + public published reads through API | controlled | admin |
| `reports` | create/read own reports | same | all |
| `notifications` / `devices` / `reminders` | own rows | own user rows | admin where required |
| `media_assets` | controlled ownership | organizer-owned assets through Go | all |
| `stories` | own writes + active reads | same | admin where required |

Every policy is evaluated after Go authorization. The exact `CREATE POLICY` statements, grants, context helper functions, and role setup are included in `EVENT_NU_TARGET_SCHEMA.sql`.

## 10.5 RLS does not replace Go authorization

Go still decides whether the operation is legal.

Example: approving an event is not a raw database update. It is a business action:

```text
Admin
 -> Go endpoint
 -> admin authorization
 -> Event moderation service
 -> transaction
 -> update event
 -> audit log
 -> notification if required
 -> commit
```

Prisma is not allowed to become a second business backend by accident.

---

# 11. Next.js Admin Architecture

Directory:

```text
apps/admin/
├── app/
├── components/
├── features/
├── lib/
│   ├── auth/
│   ├── prisma/
│   ├── api/
│   └── validation/
├── prisma/
│   └── schema.prisma
├── middleware.ts
└── ...
```

## 11.1 Authentication

Admin login:

```text
Admin browser
 -> Next.js login form
 -> Go POST /api/v1/auth/login
 -> JWT returned
 -> secure HttpOnly cookie
 -> Next.js server validates session
 -> role must be admin
```

Do not put long-lived authentication tokens in `localStorage`.

## 11.2 Admin data access

Use Prisma for selected admin queries where direct database access is useful:

```text
Next.js server
 -> Prisma
 -> admin_dashboard role
 -> RLS
 -> Neon
```

Use Go for business actions:

```text
Next.js
 -> Go API
 -> service
 -> repository
 -> Neon
```

## 11.3 Examples

Direct admin query:

```text
View users
View event list
Search moderation queue
View media jobs
View announcements
```

Go business action:

```text
Approve organizer
Block event
Restore event
Suspend user
Send notification
Change state with side effects
```

---

# 12. Flutter Architecture

Recommended structure:

```text
apps/mobile/
├── lib/
│   ├── core/
│   │   ├── network/
│   │   ├── auth/
│   │   ├── database/
│   │   ├── sync/
│   │   └── errors/
│   ├── features/
│   │   ├── auth/
│   │   ├── discover/
│   │   ├── events/
│   │   ├── organizers/
│   │   ├── venues/
│   │   ├── comments/
│   │   ├── social/
│   │   ├── rsvp/
│   │   ├── tickets/
│   │   ├── reviews/
│   │   ├── reports/
│   │   └── notifications/
│   └── main.dart
```

The exact Flutter state-management package can be chosen separately; it should not change the backend contract.

---

# 13. Offline-First Architecture

Offline sync is a core requirement, not a post-MVP feature.

## 13.1 Local database

Flutter maintains a local SQLite database.

Reads should prefer local data:

```text
UI
 -> repository
 -> local SQLite
```

Network synchronization happens independently.

## 13.2 Read synchronization

The architecture may use ElectricSQL for read replication if Neon logical replication and the selected Neon plan support it.

The intended boundary is:

```text
Neon
 -> logical replication
 -> Electric
 -> Flutter local SQLite
```

However, because the application requires Go to remain the authorization/business layer, public/private sync shapes must be carefully scoped. If Electric cannot safely fit the required authenticated filtering and Neon plan constraints, replace it with a Go-owned pull/sync protocol rather than weakening authorization.

## 13.3 Write synchronization

Electric is not the write authority.

Flutter writes to an outbox:

```text
Local action
 -> SQLite transaction
 -> outbox row
 -> UI updates immediately
```

When online:

```text
outbox
 -> Go API
 -> idempotency key
 -> transaction
 -> Neon
 -> success
 -> remove/mark outbox item synced
```

## 13.4 Outbox item

Client-side fields should include:

```text
id
operation
entity_type
entity_id
payload
idempotency_key
created_at
attempt_count
last_error
status
```

## 13.5 Conflict handling

Each mutation must define a conflict policy.

Examples:

| Action | Conflict strategy |
|---|---|
| Like | Set membership / idempotent insert |
| Save | Set membership / idempotent insert |
| Follow | Set membership / idempotent insert |
| Comment | Create once using idempotency key |
| RSVP | Server authoritative state |
| Profile edit | Last-write-wins with updated timestamp or version |
| Event edit | Organizer ownership + version check |
| Admin moderation | Server authoritative; client cannot override |
| Ticket purchase | Never blindly replay; server idempotency required |

Ticket/payment operations require special treatment and should not be considered ordinary offline mutations.

---

# 14. Media Architecture

Media files are not stored in Neon.

```text
Flutter/Admin
     |
     | request upload intent
     v
Go API
     |
     | presigned URL
     v
Cloudflare R2
     |
     v
media_assets row
     |
     v
media_processing_jobs
     |
     v
Go Worker
     |
     +--> libvips
     +--> WebP variants
     +--> thumbnails
     +--> metadata
     |
     v
R2 variants
     |
     v
CDN
     |
     v
Flutter
```

## 14.1 Required variants

Recommended:

```text
thumb  1x/2x/3x
card   1x/2x/3x
detail 1x/2x/3x
```

Keep the original for archival/quality purposes.

## 14.2 Upload security

- MIME type must be checked server-side.
- Extension alone is not trusted.
- Maximum file size enforced.
- Image dimensions validated.
- Object keys generated server-side.
- Upload authorization checked before issuing presigned URL.
- Private/admin assets should not be public by default.

---

# 15. Background Worker

The worker is a separate Go process:

```text
backend/cmd/worker/
```

Responsibilities:

- media processing;
- notification delivery;
- event reminder dispatch;
- stale job recovery;
- cleanup tasks;
- future asynchronous integrations.

## 15.1 Job lifecycle

```text
queued
  -> running
  -> completed
```

Failure:

```text
running
  -> failed
  -> retry
  -> queued
```

Use bounded retries and exponential backoff.

## 15.2 LISTEN/NOTIFY

PostgreSQL can notify the worker that a job exists.

The notification is only a wake-up signal.

The database row is the durable job state.

This means a lost notification does not lose the job.

---

# 16. Search

Use two complementary systems.

## 16.1 Keyword search

PostgreSQL `tsvector`:

```text
title + description -> search_vector -> GIN index
```

## 16.2 Semantic search

PostgreSQL `vector`/pgvector:

```text
event text
  -> embedding
  -> vector(1536)
  -> HNSW index
```

Semantic search should be introduced after the basic event search is stable.

---

# 17. Event Moderation

Moderation is based on reports plus administrative action.

## 17.1 Report states

```text
open
under_review
resolved
rejected
```

## 17.2 Moderation flow

```text
User report
  -> reports
  -> admin queue
  -> admin opens report
  -> inspect target
  -> action
      +-- dismiss
      +-- warn
      +-- block content
      +-- suspend user
      +-- disable venue
      +-- restore content
  -> audit log
```

## 17.3 Blocking an event

Blocking must be a server-side business action.

```text
POST /api/v1/admin/events/:id/block
```

Go should:

1. authenticate admin;
2. authorize admin role;
3. lock/read event state if needed;
4. update moderation status;
5. record moderation reason;
6. resolve related reports where appropriate;
7. create audit log;
8. notify organizer if required;
9. invalidate/refresh relevant caches/sync state;
10. commit transaction.

---

# 18. Venue Moderation

A venue is a first-class entity because it is used for physical navigation.

Minimum quality rules for published events:

- venue exists;
- venue is active;
- coordinates are valid;
- latitude is between -90 and 90;
- longitude is between -180 and 180;
- address/name is not empty;
- disabled venues cannot be attached to new published events.

A venue report should preserve the original report even if an admin edits the venue.

---

# 19. Security Model

## Authentication

- bcrypt password hashing;
- JWT signing key stored as a secret;
- short access-token lifetime;
- refresh-token rotation recommended;
- refresh tokens stored as hashes;
- signing algorithm explicitly restricted;
- generic invalid-credential errors to prevent account enumeration.

## Authorization

Authorization must exist at:

```text
HTTP middleware
+
Go service layer
+
PostgreSQL RLS
```

## API security

- request body size limits;
- strict JSON decoding;
- input validation;
- rate limiting;
- CORS allowlist;
- HTTPS only in production;
- secure cookies for admin sessions;
- no secrets in logs;
- no database credentials in source control.

## File security

- signed uploads;
- signed/private downloads where necessary;
- file size limits;
- MIME sniffing/validation;
- object-key randomization;
- malware scanning if threat model requires it.

---

# 20. Database Indexing Strategy

Required high-value indexes include:

```text
users(email)
users(username)
organizers(slug)
organizers(owner_user_id)
venues(organizer_id)
venues(status)
categories(slug)
events(organizer_id)
events(venue_id)
events(category_id)
events(starts_at)
events(status)
events(moderation_status)
events(search_vector) GIN
events(embedding) HNSW (`m=16`, `ef_construction=64`; benchmark and tune before production)
comments(event_id, created_at)
likes(event_id)
saves(user_id)
organizer_follows(organizer_id)
event_rsvps(event_id)
event_rsvps(user_id)
ticket_types(event_id)
orders(user_id, created_at)
orders(event_id)
tickets(user_id)
tickets(event_id)
reviews(event_id)
reports(status, created_at)
notifications(user_id, created_at)
notifications(user_id, read_at)
event_reminders(remind_at, status)
media_processing_jobs(status, updated_at)
```

Do not add indexes merely because a column exists. Index according to actual query patterns and verify with `EXPLAIN ANALYZE`.

---

# 21. Transaction Rules

A transaction is required when multiple writes must succeed or fail together.

Examples:

### RSVP

```text
BEGIN
  validate event
  check capacity
  create/update RSVP
  create reminder
  create notification if needed
COMMIT
```

### Ticket order

```text
BEGIN
  validate ticket availability
  reserve inventory
  create order
  create order items
COMMIT
```

Payment confirmation must then be processed through a separate verified provider callback/transaction.

### Event moderation

```text
BEGIN
  update event moderation state
  resolve/associate reports
  write audit log
  create notification
COMMIT
```

---

# 22. Idempotency Rules

Offline-first makes idempotency mandatory for mutation endpoints.

Mutating clients should send:

```http
Idempotency-Key: <uuid>
```

The server stores the key and the resulting response.

If the same operation is retried:

```text
same key + same request
    -> return previous result
```

If the same key is reused for a different request:

```text
409 idempotency_key_reused
```

High-priority idempotent endpoints:

- comments;
- likes;
- saves;
- follows;
- RSVP;
- ticket orders;
- review creation;
- reports;
- media completion.

---

# 23. Implementation Phases

The phases are ordered around dependencies, not UI screens.

## Phase 0 — Product and architecture contract

### Deliverables

- this specification accepted;
- domain boundaries fixed;
- actor/role model fixed;
- event lifecycle fixed;
- API conventions fixed;
- offline strategy fixed;
- RLS strategy fixed.

### Done when

No core product behavior is ambiguous enough to require redesigning the schema during implementation.

---

## Phase 1 — Repository foundation

### Build

```text
backend/
apps/mobile/
apps/admin/
```

Configure:

- Git;
- environment variables;
- Go module;
- Flutter project;
- Next.js project;
- shared documentation;
- CI skeleton.

### Done when

All applications can build independently.

---

## Phase 2 — Neon database foundation

### Build

- Neon project;
- development branch;
- staging branch strategy;
- production database;
- Goose migrations;
- database roles;
- extensions;
- base RLS framework.

### Done when

A clean Neon database can be created entirely from migrations.

---

## Phase 3 — Go API foundation

Implement:

- HTTP server;
- router;
- request IDs;
- structured logging;
- recovery;
- CORS;
- timeouts;
- JSON utilities;
- error model;
- database pool;
- graceful shutdown;
- health/readiness endpoints.

### Done when

`go fmt ./...`, `go vet ./...`, `go test ./...`, and `go build ./...` pass.

---

## Phase 4 — Authentication

Implement:

- users;
- register;
- login;
- JWT;
- role claims;
- refresh/session mechanism;
- logout/revocation;
- password reset/verification if required;
- auth middleware.

### Done when

Both Flutter and Next.js can authenticate through the same Go endpoint.

---

## Phase 5 — RLS context

Implement:

- DB roles;
- `app.user_id` context;
- `app.role` context;
- `app.organizer_id` context;
- transaction-local settings;
- policies;
- policy tests.

### Done when

A user cannot access another user's protected rows even if the application-layer authorization contains a bug.

---

## Phase 6 — Flutter offline foundation

Implement early, not at the end:

- SQLite;
- local repositories;
- local models;
- sync metadata;
- outbox;
- connectivity handling;
- retry engine;
- idempotency keys;
- conflict handling framework.

### Done when

The app can display previously synchronized data with no network connection.

---

## Phase 7 — Users and profiles

Implement:

- profile read/update;
- privacy settings;
- profile media;
- user status.

---

## Phase 8 — Organizer applications

Implement:

- application creation;
- application status;
- admin review;
- approval/rejection;
- organizer creation;
- organizer profile.

### Done when

A normal user cannot create an active organizer without admin approval.

---

## Phase 9 — Venues and categories

Implement:

- venue CRUD;
- coordinates;
- map/navigation links;
- venue ownership;
- venue moderation state;
- categories;
- venue reports.

### Done when

A published event points to a valid, active location.

---

## Phase 10 — Events/posts

Implement:

- event CRUD;
- drafts;
- publishing;
- cancellation;
- completion;
- event detail;
- ownership checks;
- event visibility;
- moderation state.

### Done when

An approved organizer can create and publish an event and a user can discover it.

---

## Phase 11 — Media

Implement:

- R2 bucket;
- upload intents;
- presigned uploads;
- media metadata;
- worker;
- image variants;
- CDN URLs;
- cleanup.

### Done when

A poster can be uploaded, processed, and displayed through an optimized variant.

---

## Phase 12 — Discovery/search

Implement:

- event listing;
- category filters;
- date filters;
- location filters;
- keyword search;
- pagination;
- ranking;
- local SQLite read model.

Semantic/vector search comes after stable lexical search.

---

## Phase 13 — Social

Implement:

- likes;
- saves;
- folders;
- shares;
- organizer follows;
- comments;
- comment moderation.

All operations must be idempotent where appropriate.

---

## Phase 14 — RSVP

Implement:

- RSVP;
- cancellation;
- capacity;
- waitlist if required;
- attendee visibility rules;
- reminder creation.

---

## Phase 15 — Tickets and payments

Implement:

- ticket types;
- order creation;
- payment integration;
- webhook verification;
- inventory locking;
- tickets;
- QR/entry code;
- cancellation/refund state.

This phase should not be considered complete until payment failure, retries, duplicate webhooks, and duplicate client requests are tested.

---

## Phase 16 — Reviews

Implement:

- review eligibility;
- rating validation;
- one-review rule;
- edit/delete;
- moderation/reporting.

---

## Phase 17 — Reporting and moderation

Implement:

- event reports;
- user reports;
- venue reports;
- comment reports;
- moderation queue;
- block/restore actions;
- audit logs;
- organizer/user notifications.

---

## Phase 18 — Notifications and reminders

Implement:

- notification records;
- device registration;
- push provider abstraction;
- event reminders;
- read/unread state;
- notification preferences.

---

## Phase 19 — Next.js admin

Build the dashboard after the underlying business domains exist.

Pages:

```text
/admin/login
/admin/dashboard
/admin/users
/admin/users/:id
/admin/organizers
/admin/organizer-applications
/admin/events
/admin/events/:id
/admin/venues
/admin/categories
/admin/reports
/admin/media
/admin/announcements
/admin/pages
/admin/audit-logs
```

---

## Phase 20 — Prisma + RLS admin data access

Implement:

- Prisma schema;
- admin DB role;
- transaction-local admin context;
- RLS policies;
- server-only Prisma usage;
- Go API integration for business actions.

### Done when

A compromised browser cannot directly obtain the database credentials and Prisma cannot bypass RLS.

---

## Phase 21 — Full synchronization

Implement:

- public event sync;
- categories;
- venues;
- private user data;
- saved events;
- notifications;
- sync checkpoints;
- retry/reconciliation;
- conflict resolution.

Validate ElectricSQL against the actual Neon plan before making it a hard dependency.

---

## Phase 22 — Production hardening

Implement:

- rate limiting;
- CORS restrictions;
- secure cookies;
- secrets management;
- RLS review;
- permission tests;
- input limits;
- file validation;
- payment security;
- audit logging;
- backup/restore testing.

---

## Phase 23 — Testing

Required test layers:

```text
Unit
Integration
Repository
HTTP handler
Authorization/RLS
Offline sync
End-to-end
Load/performance
Payment/webhook
Worker/job recovery
```

Critical authorization matrix:

| Operation | User | Organizer | Admin |
|---|---:|---:|---:|
| Read published event | yes | yes | yes |
| Create event | no | yes | yes |
| Edit own event | no | yes | yes |
| Edit another organizer event | no | no | yes |
| Block event | no | no | yes |
| Apply as organizer | yes | no | yes |
| Approve organizer | no | no | yes |
| Report event | yes | yes | yes |
| Manage own profile | yes | yes | yes |
| Manage another user | no | no | yes |
| Review event | eligible user | eligible user | moderation |
```

---

## Phase 24 — Production deployment

Target:

```text
Flutter
  -> App Store / Play Store

Next.js Admin
  -> Vercel

Go API
  -> production container platform

Go Worker
  -> separate worker service/container

Neon
  -> production PostgreSQL

Cloudflare R2
  -> object storage
```

The exact Go hosting provider can be selected independently; the architecture does not depend on Render.

---

# 24. Environment Variables

Backend:

```env
APP_ENV=production
PORT=8080
DATABASE_URL=...
DATABASE_ADMIN_URL=...
JWT_SECRET=...
JWT_EXPIRY=15m
REFRESH_TOKEN_EXPIRY=30d
CORS_ALLOWED_ORIGINS=...

R2_ENDPOINT=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET=...
R2_PUBLIC_BASE_URL=...

PUSH_PROVIDER=...
PUSH_API_KEY=...
PAYMENT_PROVIDER=...
PAYMENT_SECRET=...
```

Never commit real values.

---

# 25. Existing Repository vs Target Architecture

The uploaded repository currently contains the foundation for:

```text
users
magic_link_tokens
organizers
venues
categories
media_assets
media_variants
media_processing_jobs
events
event_gallery_items
likes
save_folders
saves
shares
stories
story_views
announcements
pages
rate_limits
```

The current implemented Go vertical slice is primarily:

```text
register
login
/me
healthz
```

The repository already contains scaffolding for domain handlers, services, repositories and DTOs, but many domain services/repositories are still TODO/stubs.

The target product additionally requires:

```text
users.role
organizer_applications
comments
organizer_follows
event_rsvps
ticket_types
orders
order_items
tickets
payments
reviews
reports
notifications
event_reminders
user_devices
auth_sessions
idempotency_keys
audit_logs
```

Therefore, implementation should be treated as an incremental migration from the scaffold to the target architecture, not as a simple completion of existing TODO files.

---

# 26. Recommended Repository Structure

```text
event_nu/
├── apps/
│   ├── mobile/                 # Flutter application
│   └── admin/                  # Next.js admin application
│
├── backend/
│   ├── cmd/
│   │   ├── api/
│   │   └── worker/
│   │
│   ├── internal/
│   │   ├── api/
│   │   │   ├── dto/
│   │   │   ├── handlers/
│   │   │   ├── middleware/
│   │   │   └── routes/
│   │   ├── config/
│   │   ├── domain/
│   │   ├── infrastructure/
│   │   │   ├── database/
│   │   │   ├── imaging/
│   │   │   ├── payments/
│   │   │   ├── push/
│   │   │   └── storage/
│   │   ├── repository/
│   │   ├── service/
│   │   └── shared/
│   │
│   ├── migrations/
│   ├── docs/
│   ├── test/
│   ├── Dockerfile
│   └── go.mod
│
├── docs/
│   ├── IMPLEMENTATION.md
│   ├── API.md
│   ├── DATABASE.md
│   ├── SECURITY.md
│   ├── SYNC.md
│   └── OPERATIONS.md
│
├── .github/
│   └── workflows/
│
└── README.md
```

This document can initially serve as the master document, then be split into smaller documents as implementation grows.

---

# 27. Definition of Done

A feature is not complete when the endpoint works once.

A feature is complete when:

```text
Database
  + migration
  + constraints
  + indexes
  + RLS

Backend
  + entity
  + repository
  + service
  + handler
  + validation
  + authorization
  + errors
  + idempotency where needed

Flutter
  + local model
  + offline behavior
  + sync behavior
  + UI state
  + error handling

Admin
  + dashboard UI if applicable
  + Prisma query if appropriate
  + Go business action if required
  + RLS
  + audit trail

Testing
  + unit tests
  + integration tests
  + authorization tests
  + offline tests

Operations
  + logging
  + monitoring
  + failure recovery
```

---

# 28. Production Readiness Checklist

## Database

- [ ] Neon production project configured
- [ ] migrations reproducible
- [ ] backup/restore tested
- [ ] indexes reviewed
- [ ] RLS policies tested
- [ ] database roles restricted
- [ ] no application uses owner credentials

## Go API

- [ ] authentication complete
- [ ] refresh/revocation complete
- [ ] authorization complete
- [ ] all business actions transactional
- [ ] rate limiting enabled
- [ ] CORS restricted
- [ ] request limits enabled
- [ ] structured logs
- [ ] health/readiness endpoints
- [ ] graceful shutdown

## Flutter

- [ ] local DB
- [ ] offline reads
- [ ] write outbox
- [ ] retry mechanism
- [ ] idempotency
- [ ] conflict handling
- [ ] secure token storage
- [ ] push notifications

## Admin

- [ ] secure login
- [ ] admin role enforcement
- [ ] HttpOnly cookie
- [ ] server-side Prisma only
- [ ] RLS enabled
- [ ] moderation actions audited
- [ ] business actions routed through Go

## Media

- [ ] R2 bucket
- [ ] upload authorization
- [ ] size/type validation
- [ ] processing worker
- [ ] retries
- [ ] CDN
- [ ] cleanup

## Payments

- [ ] provider selected
- [ ] server-side payment verification
- [ ] webhook signature verification
- [ ] duplicate webhook handling
- [ ] idempotent order creation
- [ ] refund/cancellation state

## Sync

- [ ] offline read tested
- [ ] offline writes tested
- [ ] reconnect tested
- [ ] duplicate request tested
- [ ] out-of-order operations tested
- [ ] conflict rules tested
- [ ] authorization maintained offline/after reconnect

---

# 29. Architectural Rules — Do Not Violate

1. **Flutter never connects directly to Neon.**
2. **Regular users never connect directly to PostgreSQL.**
3. **Authentication is owned by Go.**
4. **Admin authentication reuses Go's login endpoint.**
5. **`users.role` contains only `user` and `admin`.**
6. **Organizer is a domain entity, not a user role.**
7. **Organizer creation requires admin approval.**
8. **Go owns business logic.**
9. **Prisma is not a replacement for the Go business layer.**
10. **Admin direct database access is protected by a separate PostgreSQL role and RLS.**
11. **Go database access must eventually participate in RLS rather than universally bypass it.**
12. **RLS is defense in depth, not the sole authorization mechanism.**
13. **Event reports do not automatically equal event deletion.**
14. **Admin moderation actions must be audited.**
15. **Venue coordinates are first-class data.**
16. **Media bytes do not belong in PostgreSQL.**
17. **Offline writes require idempotency.**
18. **Payment operations are server-authoritative.**
19. **Money is stored as integer minor units plus currency.**
20. **All production secrets remain outside source control.**
21. **Database schema changes happen through migrations.**
22. **Business operations that cause side effects go through Go services.**
23. **A notification is a database record first and a push delivery second.**
24. **A background notification is never the sole source of truth for an important state change.**
25. **Every feature must define its offline behavior before Flutter implementation is considered complete.**

---

# 30. Final System Model

The completed Event Nu system should behave like this:

```text
                             USER
                              |
                              v
                         Flutter App
                              |
                  +-----------+-----------+
                  |                       |
             Local SQLite             Go REST API
                  |                       |
             Offline reads                |
                  |                       v
                  |                 Auth / Services
                  |                       |
                  |                 Repositories
                  |                       |
                  |                       v
                  |                Neon PostgreSQL
                  |                       |
                  |                    RLS
                  |                       |
                  +------ Sync -----------+


                            ORGANIZER
                               |
                               v
                          Flutter App
                               |
                               v
                           Go REST API
                               |
                         Organizer Service
                               |
                         Event Service
                               |
                               v
                         Neon PostgreSQL


                              ADMIN
                               |
                               v
                         Next.js Admin
                          /          \
                         /            \
                    Prisma          Go REST API
                      |                  |
                    RLS             Business actions
                      |                  |
                      +--------+---------+
                               |
                               v
                         Neon PostgreSQL


                           ASYNC WORK
                               |
                               v
                           Go Worker
                         /     |      \
                    Media  Notifications  Jobs
                      |         |           |
                      v         v           v
                    R2      Push provider  Neon
```

This is the architecture to implement incrementally. The existing repository is the starting scaffold; the target schema and phases in this document define the complete application rather than pretending that the currently implemented authentication slice already represents the finished product.

---

# Appendix A — Current Scaffold Verification Commands

Before extending the existing backend:

```bash
cd backend

go mod tidy
go fmt ./...
go vet ./...
go test ./...
go build ./...
```

Then run the application against a development Neon branch.

Do not proceed to large domain implementation until the foundation passes these checks.

---

# Appendix B — Initial Migration Order

Recommended target migration sequence:

```text
00001_core.sql
00002_auth_sessions_and_roles.sql
00003_organizers_and_applications.sql
00004_venues_and_categories.sql
00005_media.sql
00006_events.sql
00007_comments_and_social.sql
00008_rsvp.sql
00009_tickets_and_payments.sql
00010_reviews.sql
00011_reports_and_moderation.sql
00012_notifications_and_reminders.sql
00013_stories.sql
00014_announcements_pages.sql
00015_idempotency_and_audit.sql
00016_rls.sql
00017_indexes_and_search.sql
00018_scheduled_jobs.sql
```

The exact numbering can differ if the existing migration history is preserved. Never rewrite already-applied production migrations; add forward migrations.

---

# Appendix C — Current Implementation Boundary

At the time this document was created, the existing scaffold has the strongest implementation around:

```text
users
authentication
JWT
GET /users/me
health check
```

The rest of the domain should be implemented in the dependency order specified above.

The goal is not to create every table and endpoint first. The goal is to build **verified vertical slices** while preserving the complete architecture:

```text
Database
 -> Repository
 -> Service
 -> REST API
 -> Flutter/Admin
 -> Offline behavior
 -> Tests
 -> Observability
```

That approach prevents the project from becoming a large collection of database tables and TODO handlers without a functioning product workflow.
