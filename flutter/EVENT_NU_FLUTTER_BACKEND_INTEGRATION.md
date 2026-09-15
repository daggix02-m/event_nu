# EVENT_NU --- Flutter Mobile Application & Go Backend Integration

**Purpose:** Implementation source of truth for the Flutter mobile app
and its integration with the EVENT_NU Go REST API.

**System:** Flutter mobile app → Go REST API → Neon PostgreSQL.\
**Admin:** Separate Next.js admin app. Flutter does not connect directly
to Neon, Prisma, PostgreSQL, or RLS.

------------------------------------------------------------------------

## 1. System Architecture

``` text
Regular User / Organizer
          │
          ▼
     Flutter App
          │ HTTPS / JSON
          ▼
      Go REST API
          │
     ┌────┴─────┐
     ▼          ▼
   Neon       Worker
 PostgreSQL
     │
     └── RLS / constraints

Admin → Next.js Admin → Go auth/API + Prisma → Neon
```

Flutter owns presentation, navigation, local state, caching, offline
storage, synchronization, optimistic UI, device capabilities,
notifications, and deep links.

Go owns authentication, authorization, business rules, validation,
transactions, payments, ticket inventory, moderation, event lifecycle,
organizer approval, and authoritative server state.

**Rule:** Flutter must never bypass the Go API to access PostgreSQL.

------------------------------------------------------------------------

# 2. Product Actors

## Regular user

A regular user can:

-   register/login
-   verify email
-   manage profile
-   discover events
-   view events and venues
-   navigate to an event location
-   comment on events
-   like/save/follow supported resources
-   RSVP/register
-   buy tickets
-   receive event reminders
-   review/rate eligible events
-   report events
-   report users
-   report venue misinformation
-   apply to become an organizer

## Organizer

Organizer is not a separate account type. An approved user owns an
`organizers` row.

``` text
users
  │
  └── organizer application
          │
       approved
          │
          ▼
     organizers
       │
       └── owner_user_id → users.id
```

## Admin

`users.role` is `user | admin`. Organizer remains a domain relationship,
not a user role.

------------------------------------------------------------------------

# 3. Flutter Architecture

Recommended structure:

``` text
lib/
├── app/
│   ├── app.dart
│   ├── router/
│   └── theme/
├── core/
│   ├── api/
│   │   ├── api_client.dart
│   │   ├── api_envelope.dart
│   │   ├── api_exception.dart
│   │   └── auth_interceptor.dart
│   ├── auth/
│   ├── storage/
│   ├── connectivity/
│   ├── sync/
│   ├── notifications/
│   ├── deep_links/
│   └── configuration/
├── features/
│   ├── auth/
│   ├── home/
│   ├── events/
│   ├── venues/
│   ├── categories/
│   ├── organizer_applications/
│   ├── organizer/
│   ├── comments/
│   ├── social/
│   ├── rsvp/
│   ├── tickets/
│   ├── payments/
│   ├── reviews/
│   ├── reports/
│   ├── notifications/
│   └── profile/
└── shared/
    ├── widgets/
    ├── skeletons/
    ├── forms/
    └── pagination/
```

Every feature follows:

``` text
presentation
    ↓
state/controller
    ↓
repository
    ↓
remote datasource + local datasource
```

Flutter models should represent API DTOs/domain data, not PostgreSQL
tables directly.

------------------------------------------------------------------------

# 4. Global UI Requirements

Every data-dependent page MUST implement:

``` text
initial
loading
loaded
empty
refreshing
error
offline
```

### Skeleton requirement

Every major data-dependent screen must have a screen-specific skeleton:

-   Home
-   event lists
-   event details
-   search
-   venues
-   venue details
-   organizer profile
-   organizer dashboard
-   organizer events
-   event editor
-   organizer application
-   comments
-   reviews
-   saved events
-   notifications
-   tickets
-   profile
-   reports
-   RSVP screens

Do not replace a full page with a generic spinner when a skeleton can
represent its content.

### Fast UI requirement

Flutter should render cached/local data immediately whenever possible.

``` text
Open screen
  ↓
Local DB/cache
  ↓
Render immediately
  ↓
Background API request
  ↓
Reconcile with server
  ↓
Update local DB/UI
```

Safe interactions such as save/like/follow should normally be
optimistic.

Server-authoritative operations such as payment, ticket inventory, and
authorization-sensitive actions must show a pending state until
confirmed.

------------------------------------------------------------------------

# 5. HTTP/API Contract

Base path:

``` text
/api/v1
```

All bodies are JSON.

Success:

``` json
{"data": ...}
```

Paginated response:

``` json
{
  "data": [],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 137,
    "has_next": true
  }
}
```

Error:

``` json
{
  "error": {
    "code": "some_error",
    "message": "Human readable message"
  }
}
```

The API client must unwrap envelopes centrally. UI code must not parse
raw response shapes independently.

Unknown JSON fields are rejected by the backend, so Flutter must send
only documented fields.

The backend has a 1 MiB request body cap.

------------------------------------------------------------------------

# 6. Authentication

## Register

``` http
POST /api/v1/auth/register
```

Request:

``` json
{
  "email": "user@example.com",
  "password": "password",
  "username": "username"
}
```

Response includes:

``` text
user
access_token
refresh_token
expires_in_seconds
```

Default access token lifetime is 15 minutes; refresh token lifetime is
30 days.

Registration queues a welcome email and a six-digit verification email
asynchronously.

## Login

``` http
POST /api/v1/auth/login
```

Request:

``` json
{
  "email": "user@example.com",
  "password": "password"
}
```

Invalid login returns the same `401 invalid_credentials` response
whether the email does not exist or the password is wrong. Flutter must
not distinguish these cases.

## Refresh

``` http
POST /api/v1/auth/refresh
```

``` json
{"refresh_token": "..."}
```

The refresh token is single-use and rotates.

Flutter MUST serialize refresh calls:

``` text
Request gets 401
   ↓
Is refresh already running?
   ├── yes → await existing refresh
   └── no → start one refresh
                 ↓
            store new tokens
                 ↓
            retry original request once
```

If refresh fails, log out. Never loop indefinitely.

## Logout

``` http
POST /api/v1/auth/logout
```

``` json
{"refresh_token": "..."}
```

Clear secure credentials and authenticated state after logout.

------------------------------------------------------------------------

# 7. Secure Token Storage

Use `flutter_secure_storage` or an equivalent platform-secure storage
mechanism.

Store:

``` text
access_token
refresh_token
access_token_expiry
```

Never store authentication tokens in ordinary preferences such as
`SharedPreferences`.

The app should proactively refresh shortly before expiration or refresh
on a `401`.

------------------------------------------------------------------------

# 8. Email Verification and Deep Links

Verification deep link:

``` text
eventnu://verify
```

Flutter must receive the link, extract the verification code, then call:

``` http
POST /api/v1/auth/verify
```

``` json
{"code": "123456"}
```

There is no GET verification endpoint.

After successful verification:

``` text
POST /auth/verify
        ↓
GET /users/me
        ↓
is_verified = true
```

Do not invent a verification response DTO.

------------------------------------------------------------------------

# 9. Current User

``` http
GET /api/v1/users/me
```

The Flutter user model should include:

``` text
id
email
username
bio
photo_url
role
is_verified
created_at
```

Organizer state should come from the organizer/application workflow, not
from a fabricated `organizer` role.

------------------------------------------------------------------------

# 10. Organizer Application

Any authenticated user can apply.

``` http
POST /api/v1/organizer-applications
```

Request:

``` json
{
  "requested_name": "...",
  "requested_slug": "...",
  "bio": "..."
}
```

Send an `Idempotency-Key`.

Check status:

``` http
GET /api/v1/organizer-applications/me
```

States:

``` text
pending
approved
rejected
```

Only one pending application is allowed.

`409 application_pending` means a pending application already exists.

Admin approval/rejection happens in the separate Next.js admin
application.

------------------------------------------------------------------------

# 11. Categories

``` http
GET /api/v1/categories
```

Categories are seeded fixed lookup data:

``` text
id
slug
name
```

Flutter has read-only access.

Cache categories locally because they change infrequently.

------------------------------------------------------------------------

# 12. Venues

Public:

``` http
GET /api/v1/venues
```

Organizer:

``` http
POST /api/v1/venues
```

Request:

``` json
{
  "name": "...",
  "address": "...",
  "latitude": 0.0,
  "longitude": 0.0,
  "place_id": "...",
  "city": "...",
  "country_code": "ET"
}
```

Venue is a real location. Flutter should show:

``` text
venue name
address
map preview
location
Get Directions
```

Use latitude/longitude to open the device's supported maps/navigation
application.

Venue misinformation reports go through the report system; Flutter
should confirm submission but not independently mark a venue as false.

------------------------------------------------------------------------

# 13. Events

Public:

``` http
GET /api/v1/events
GET /api/v1/events/{id}
```

Organizer:

``` http
POST /api/v1/events
PATCH /api/v1/events/{id}
POST /api/v1/events/{id}/publish
```

Create/update request:

``` json
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

Dates must be RFC3339 timestamps.

------------------------------------------------------------------------

# 14. Event Lifecycle

Event status:

``` text
draft
published
cancelled
completed
archived
```

Moderation status is separate:

``` text
clean
reported
blocked
```

Example:

``` text
status = published
moderation_status = blocked
```

A published event can therefore disappear from public discovery without
changing its event status.

Public discovery is server/RLS controlled. Flutter must not recreate the
backend's visibility rules as its source of truth.

## Draft

Organizer can edit.

## Published

Editing/publishing through the specified endpoints is no longer allowed.

Flutter should disable edit/publish buttons when:

``` text
event.status != draft
```

but still handle `409 event_not_draft` because cached state can be
stale.

## Blocked

The event should no longer be presented as publicly available after the
backend reports it as blocked.

------------------------------------------------------------------------

# 15. Publishing

``` http
POST /api/v1/events/{id}/publish
```

No body.

Success returns the updated event with:

``` text
status = published
```

Second publish:

``` text
409 event_not_draft
```

UI:

``` text
Draft
 ├── Edit
 └── Publish

Published
 ├── View
 └── Edit disabled
```

------------------------------------------------------------------------

# 16. Pagination

Events and venues:

``` text
GET /events?page=1&limit=20
GET /venues?page=1&limit=20
```

Rules:

``` text
default page = 1
default limit = 20
maximum limit = 100
```

Use:

``` text
pagination.has_next
```

to determine whether another page exists.

Never use:

``` text
items.length < limit
```

as the authoritative pagination test.

Flutter should prevent duplicate concurrent page loads.

------------------------------------------------------------------------

# 17. Event Discovery UX

Recommended flow:

``` text
Home
 ↓
Local cached events
 ↓
Immediate render
 ↓
Background refresh
 ↓
Server events
 ↓
Update local DB
 ↓
UI refresh
```

The event list should support:

``` text
skeleton
pull-to-refresh
infinite scroll
empty state
error + retry
offline cached state
```

The public list should rely on the backend/RLS for visibility.

------------------------------------------------------------------------

# 18. Event Details

The detail screen should show, where data is available:

``` text
cover image
title
organizer
category
date/time
description
venue
price
capacity/action information
RSVP/ticket action
comments
reviews
social actions
report
```

Independent sections should load independently where practical.

For example:

``` text
Event information → loaded
Comments → skeleton
Reviews → skeleton
```

A slow comments endpoint must not block the event header.

------------------------------------------------------------------------

# 19. Comments

Required product behavior:

``` text
Event
 ↓
Comments
 ↓
Read
 ↓
Create comment
```

Use the backend for:

``` text
ownership
validation
persistence
moderation
```

For safe supported writes:

``` text
create locally
 ↓
show pending comment
 ↓
sync/API
 ↓
replace temporary state with server state
```

If a particular write is not included in the backend synchronization
contract, it must remain online-required rather than pretending it was
synchronized.

------------------------------------------------------------------------

# 20. Likes, Saves, Follows

These should be designed for immediate feedback.

``` text
Tap Save
 ↓
local state = saved
 ↓
UI updates immediately
 ↓
API/outbox
 ↓
server confirmation
```

On permanent failure:

``` text
rollback local state
 ↓
show error
```

Offline-capable social actions should enter the outbox.

------------------------------------------------------------------------

# 21. RSVP / Registration

User flow:

``` text
Event
 ↓
RSVP/Register
 ↓
pending
 ↓
server confirmation
 ↓
registered
```

The backend decides:

``` text
eligibility
capacity
event state
duplicate registration
authorization
```

Flutter must never use locally cached capacity as the final authority.

If RSVP is included in the backend sync contract, offline RSVP may be
queued. Otherwise, show that connectivity is required.

------------------------------------------------------------------------

# 22. Tickets

Ticket purchase is server-authoritative.

``` text
Event
 ↓
Ticket selection
 ↓
Quantity
 ↓
Create order
 ↓
Payment
 ↓
Backend verification
 ↓
Ticket issued
```

Flutter states:

``` text
idle
selecting
creating_order
payment_required
processing
success
failed
cancelled
expired
```

Do not mark payment as successful from a client-side payment callback
alone.

------------------------------------------------------------------------

# 23. Payment

The authoritative flow is:

``` text
Flutter
 ↓
Create order
 ↓
Go
 ↓
Payment provider
 ↓
Provider webhook
 ↓
Go verifies webhook
 ↓
Payment becomes confirmed
 ↓
Ticket issued
 ↓
Flutter syncs/fetches final state
```

Flutter must display a pending/processing state while waiting.

Already-issued tickets should remain available offline if the product
requires offline ticket presentation.

------------------------------------------------------------------------

# 24. Reviews / Ratings

User can review/rate an eligible event.

``` text
Completed / eligible event
 ↓
Review action
 ↓
Rating 1–5
 ↓
Optional text
 ↓
Submit
```

Backend must determine eligibility and enforce duplicate/validity rules.

Flutter may hide the review action until eligibility is apparent, but
cannot rely on the client check for security.

------------------------------------------------------------------------

# 25. Reports

Users can report:

``` text
event
user
venue / venue misinformation
```

Flow:

``` text
Report
 ↓
Reason
 ↓
Optional details
 ↓
Submit
 ↓
Report submitted
```

Flutter should never directly block the reported resource.

The backend/admin system decides moderation outcomes.

------------------------------------------------------------------------

# 26. Notifications

Flutter handles:

``` text
notification permission
device token
foreground handling
background handling
notification tap
deep link
notification inbox
```

Backend/worker handles:

``` text
who receives notification
why it is sent
when it is sent
```

Event reminder example:

``` text
RSVP
 ↓
backend/worker
 ↓
push provider
 ↓
Flutter
 ↓
user taps
 ↓
event detail
```

------------------------------------------------------------------------

# 27. Media

Flutter should not put media in PostgreSQL.

Recommended:

``` text
Flutter selects media
       ↓
request upload authorization
       ↓
upload to object storage
       ↓
backend/media record
       ↓
processing
       ↓
optimized/CDN media
       ↓
Flutter displays result
```

UI states:

``` text
selecting
uploading
processing
ready
failed
retrying
```

Cache optimized images/thumbnails, not every original asset.

------------------------------------------------------------------------

# 28. Local Database

Local persistence should contain data required for offline UX.

Examples:

``` text
events
venues
categories
organizers
user/profile cache
notifications
local user state
sync operations
```

Separate:

``` text
secure credentials
```

from:

``` text
normal application cache
```

------------------------------------------------------------------------

# 29. Offline Sync

Offline sync is a core implementation concern.

``` text
                 Repository
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
      Local DB             Go API
          │                   │
          └─────────┬─────────┘
                    ▼
                Sync Engine
```

Read:

``` text
local data → immediate UI
server → background synchronization
```

Write:

``` text
user action
 ↓
local state/outbox
 ↓
network returns
 ↓
Go API
 ↓
server result
 ↓
reconcile local state
```

The server is authoritative for financial, inventory, authorization,
moderation, and other critical state.

------------------------------------------------------------------------

# 30. Outbox

Conceptual local entity:

``` text
sync_operation
├── operation_id
├── entity_type
├── entity_id
├── operation_type
├── payload
├── created_at
├── attempt_count
├── status
└── last_error
```

States:

``` text
pending
processing
completed
failed
```

A successful server response removes the operation from the active
queue.

Transient failures retry with backoff.

Permanent failures are surfaced to the feature state.

------------------------------------------------------------------------

# 31. Conflict Resolution

Use server authority according to feature type.

``` text
Likes/saves/follows
→ idempotent last-valid-state behavior

Comments
→ do not overwrite another user's server data

Events
→ server version wins for conflicting changes

Tickets
→ server wins

Payments
→ server wins

Moderation
→ server wins
```

Never implement a universal:

``` text
local data overwrites server
```

strategy.

------------------------------------------------------------------------

# 32. Idempotency

Supported endpoints:

``` text
POST /organizer-applications
POST /venues
POST /events
```

Generate one UUID v4 for each logical submit.

Example:

``` text
Create event
 ↓
Key = UUID-A
 ↓
request times out
 ↓
retry using UUID-A
```

Never create UUID-B for the same retry.

The key should live in the form/state for the duration of that
submit-and-retry operation.

------------------------------------------------------------------------

# 33. API Errors

Known codes:

``` text
invalid_credentials
account_suspended
email_taken
username_taken
bad_request
unauthorized
not_found
too_many_requests
application_pending
application_not_pending
event_not_draft
idempotency_key_reused
idempotency_in_progress
```

Central mapping:

``` text
API error code
 ↓
typed application exception
 ↓
feature state
 ↓
user-friendly UI
```

Unknown codes should fall back to a generic error.

------------------------------------------------------------------------

# 34. Rate Limit UX

A rate-limited response is:

``` text
429 too_many_requests
```

and includes:

``` http
Retry-After: <seconds>
```

Flutter should display a countdown or retry message using the actual
value.

Do not automatically retry in a tight loop.

------------------------------------------------------------------------

# 35. Network Failure UX

If cached data exists:

``` text
network unavailable
 ↓
keep showing cached content
 ↓
offline indicator
 ↓
retry/sync later
```

Do not replace useful cached content with:

``` text
Something went wrong
```

unless there is no usable data.

------------------------------------------------------------------------

# 36. Loading Strategy

### Initial load

``` text
No local data
 ↓
screen skeleton
 ↓
API
 ↓
content
```

### Cached load

``` text
local data
 ↓
content immediately
 ↓
background API
```

### Refresh

``` text
existing content remains visible
 ↓
refresh indicator
 ↓
new data
```

### Independent sections

``` text
Event header → loaded
Venue → loaded
Comments → loading skeleton
Reviews → loading skeleton
```

This prevents one slow backend request from blocking the entire screen.

------------------------------------------------------------------------

# 37. Time Handling

Backend event timestamps are RFC3339.

Flutter must:

-   parse timezone-aware timestamps
-   preserve the actual instant
-   display in the appropriate local timezone
-   send RFC3339 timestamps
-   never send date-only values to timestamp fields

Example:

``` text
Server:
2026-10-01T18:00:00Z

Flutter:
1 Oct
9:00 PM
```

------------------------------------------------------------------------

# 38. Search and Lists

Use paginated requests rather than downloading all data.

A list controller should track:

``` text
items
page
limit
hasNext
loading
loadingMore
refreshing
error
```

For search:

``` text
search input
 ↓
debounce
 ↓
API request
 ↓
results
```

Local search can operate against cached data when appropriate.

------------------------------------------------------------------------

# 39. Organizer Event Creation

``` text
Organizer Dashboard
 ↓
Create Event
 ↓
Basic Info
 ↓
Category
 ↓
Venue
 ↓
Date/time
 ↓
Pricing
 ↓
Capacity/action
 ↓
Media
 ↓
Save Draft
 ↓
Publish
```

The form should perform local validation for immediate feedback.

Go performs final validation.

Create request uses an idempotency key.

------------------------------------------------------------------------

# 40. Organizer Event Management

The organizer's event area should distinguish:

``` text
Drafts
Published
Cancelled
Completed
Archived
```

Drafts:

``` text
edit
publish
```

Published:

``` text
view
```

If the backend reports a stale/conflicting state, refresh and reconcile.

------------------------------------------------------------------------

# 41. Profile and Account UX

Profile should support:

``` text
profile information
verification state
organizer application state
organizer dashboard entry when approved
saved events
tickets
reviews
```

Sensitive account information should not be stored unnecessarily in
local cache.

------------------------------------------------------------------------

# 42. Navigation Model

Conceptually:

``` text
Splash
  │
  ├── Unauthenticated
  │     ├── Login
  │     ├── Register
  │     └── Verify
  │
  └── Authenticated
        ├── Home
        ├── Discover/Search
        ├── Saved
        ├── Tickets
        └── Profile
              └── Organizer
```

Deep links should resolve into the same navigation system.

------------------------------------------------------------------------

# 43. Recommended Flutter State Model

Every feature should have explicit states.

Example event list:

``` text
EventListState
├── items
├── loading
├── refreshing
├── loadingMore
├── hasNext
├── error
└── offline
```

Example purchase:

``` text
PurchaseState
├── idle
├── creatingOrder
├── paymentRequired
├── processing
├── success
└── failure
```

Example organizer application:

``` text
ApplicationState
├── initial
├── loading
├── pending
├── approved
├── rejected
└── error
```

------------------------------------------------------------------------

# 44. Implementation Order

The frontend must be built in dependency order.

``` text
1. Flutter project foundation
       ↓
2. API client
       ↓
3. Secure token storage
       ↓
4. Local database
       ↓
5. Connectivity layer
       ↓
6. Sync infrastructure/outbox
       ↓
7. Authentication
       ↓
8. User profile
       ↓
9. Categories
       ↓
10. Organizer application
       ↓
11. Organizer state
       ↓
12. Venues
       ↓
13. Event discovery
       ↓
14. Event details
       ↓
15. Organizer event creation
       ↓
16. Event publishing
       ↓
17. Comments/social
       ↓
18. RSVP
       ↓
19. Tickets
       ↓
20. Payments
       ↓
21. Reviews
       ↓
22. Reports
       ↓
23. Notifications
       ↓
24. Media
       ↓
25. Full offline reconciliation
       ↓
26. Security/performance hardening
       ↓
27. Integration/E2E testing
       ↓
28. Production release
```

------------------------------------------------------------------------

# 45. First Vertical Slice

Do not build every screen before connecting the backend.

First prove:

``` text
Register
 ↓
Login
 ↓
User session
 ↓
Home
 ↓
Events
 ↓
Event details
 ↓
Venue
 ↓
Directions
```

Then prove the organizer path:

``` text
User
 ↓
Organizer application
 ↓
Admin approval
 ↓
Organizer mode
 ↓
Create venue
 ↓
Create draft
 ↓
Edit draft
 ↓
Publish
 ↓
User discovers published event
```

This is the first major end-to-end milestone.

------------------------------------------------------------------------

# 46. Feature Completion Standard

A feature is not finished when the UI looks correct.

Every feature must have:

### UI

``` text
✓ skeleton
✓ loaded
✓ empty
✓ error
✓ offline
✓ refreshing
✓ pending/success where applicable
```

### API

``` text
✓ correct endpoint
✓ correct HTTP method
✓ correct request body
✓ correct response model
✓ authentication
✓ authorization handling
✓ error mapping
```

### State

``` text
✓ local state
✓ remote state
✓ cache
✓ sync where supported
✓ conflict handling where required
```

### Testing

``` text
✓ model/parsing tests
✓ repository tests
✓ state tests
✓ widget tests
✓ integration tests
✓ E2E tests for critical workflows
```

------------------------------------------------------------------------

# 47. Production Testing Matrix

## Authentication

Test:

-   registration
-   duplicate email
-   duplicate username
-   login
-   invalid credentials
-   suspended account
-   verification
-   deep link verification
-   token expiry
-   token refresh
-   concurrent refresh
-   logout

## Organizer

Test:

-   application
-   pending application
-   duplicate pending application
-   approval
-   rejection
-   organizer access
-   ownership boundaries

## Events

Test:

-   create draft
-   edit draft
-   publish
-   publish twice
-   edit published event
-   public discovery
-   blocked event
-   cancelled event
-   completed event
-   pagination
-   refresh
-   offline cache

## Ticket/payment

Test:

-   ticket availability
-   sold out
-   concurrent purchase
-   order creation
-   payment pending
-   payment success
-   payment failure
-   duplicate webhook
-   ticket issuance
-   offline ticket display

## Offline

Test:

-   cold start offline
-   cached discovery
-   offline safe action
-   outbox persistence
-   reconnect
-   retries
-   duplicate operations
-   conflicts
-   server rejection
-   logout with pending operations

------------------------------------------------------------------------

# 48. Security Requirements

Flutter must:

-   use HTTPS in production
-   securely store tokens
-   never log tokens
-   never store database credentials
-   never store Neon credentials
-   never store Prisma credentials
-   never access PostgreSQL directly
-   never trust client-side authorization
-   handle `401` and `403`
-   handle account suspension
-   protect sensitive cached information
-   clear session state on logout

RLS is not something Flutter calls directly. The security chain is:

``` text
Flutter
 ↓
Go authentication
 ↓
Go authorization
 ↓
database access
 ↓
PostgreSQL RLS/constraints
```

------------------------------------------------------------------------

# 49. What Flutter Must NOT Implement

Do not reproduce backend business logic as the authority.

Do not implement:

``` text
SQL
PostgreSQL access
RLS logic
Prisma
database credentials
payment verification
ticket inventory authority
admin authorization
event moderation authority
```

Client-side checks are for UX; server-side checks are for correctness
and security.

------------------------------------------------------------------------

# 50. Performance Requirements

The Flutter application should:

-   render cached data immediately
-   use skeletons for genuinely unloaded content
-   avoid blocking unrelated UI
-   paginate lists
-   lazy-load long lists
-   cache appropriate resources
-   cache optimized images
-   use optimistic updates for safe operations
-   perform background synchronization
-   avoid unnecessary rebuilds
-   avoid repeated duplicate requests
-   serialize token refresh
-   avoid retry loops

The goal is that the application feels responsive even when the Go API
or network is slow.

------------------------------------------------------------------------

# 51. Backend Integration Checklist

Before implementing a Flutter feature, identify:

``` text
[ ] Backend endpoint
[ ] HTTP method
[ ] Authentication requirement
[ ] Request DTO
[ ] Response DTO
[ ] Error codes
[ ] Pagination behavior
[ ] Idempotency requirement
[ ] Offline capability
[ ] Cache policy
[ ] Optimistic-update policy
[ ] Loading skeleton
[ ] Empty state
[ ] Error state
[ ] Offline state
[ ] Retry behavior
[ ] Integration tests
```

------------------------------------------------------------------------

# 52. Source-of-Truth Rules

``` text
Flutter UI state
→ presentation concern

Flutter local DB
→ cache/offline concern

Go API
→ business/API authority

Neon PostgreSQL
→ durable source of truth

PostgreSQL RLS
→ database defense-in-depth

Next.js Admin
→ administration interface
```

Flutter must always reconcile critical state with the server.

------------------------------------------------------------------------

# 53. Final Integration Model

``` text
                         FLUTTER
                            │
                    ┌───────┴────────┐
                    │                │
              Presentation       Core Services
                    │                │
                 State          API / Storage
                    │                │
                 Domain        Sync / Auth
                    │                │
                    └───────┬────────┘
                            │
                    Repository Layer
                       /                                /                           Local DB          Go API
                   │                │
                   │                ▼
                   │           Go Services
                   │                │
                   │                ▼
                   └────────────── Neon
                                  │
                                  ▼
                                 RLS
```

## Golden rule

**Build every feature as:**

``` text
Requirement
    ↓
Backend API contract
    ↓
Flutter model
    ↓
Remote datasource
    ↓
Local datasource
    ↓
Repository
    ↓
State
    ↓
UI
    ↓
Skeleton/loading/empty/error/offline states
    ↓
Sync/optimistic behavior
    ↓
Tests
```

The Flutter app should therefore be a **fast, local-first,
offline-capable client of the Go backend**, while Go and PostgreSQL
remain authoritative for security, business rules, transactions,
inventory, payments, moderation, and persistent state.

## Verified API surface currently documented

``` text
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/verify
POST /api/v1/auth/logout
GET  /api/v1/users/me

POST /api/v1/organizer-applications
GET  /api/v1/organizer-applications/me

GET  /api/v1/venues
GET  /api/v1/categories
GET  /api/v1/events
GET  /api/v1/events/{id}

POST  /api/v1/venues
POST  /api/v1/events
PATCH /api/v1/events/{id}
POST /api/v1/events/{id}/publish
```

For product features whose exact backend endpoints/DTOs are not present
in the supplied API contract, Flutter must use the actual Go routes and
DTOs when those contracts are available rather than inventing endpoint
names or request fields.
