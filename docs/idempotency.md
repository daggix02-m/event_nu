# Idempotency for Client-Retryable Writes

Decision log for the client-supplied `Idempotency-Key` middleware (WS9, spec
§8.29/§22). Offline-first mobile clients retry on flaky networks; without an
idempotency guard a retried request duplicates a create. This document records
what is protected, the mechanism, and what is intentionally *safe without it*.

## Protected endpoints (opt-in via `Idempotency-Key` header)

`Idempotency-Key: <key>` is honored on the three mobile-retryable POSTs
(`backend/internal/api/routes/routes.go`):

| Method | Path | Middleware |
|---|---|---|
| POST | `/api/v1/organizer-applications` | `RequireAuth → SetRLS → Idempotency` |
| POST | `/api/v1/venues` | `RequireAuth → SetRLS → Idempotency` |
| POST | `/api/v1/events` | `RequireAuth → SetRLS → Idempotency` |

The header is **optional**: requests without it run through unchanged (opt-in,
so existing clients keep working and read-only-style calls pay nothing).

## Mechanism

- `middleware.Idempotency` (`backend/internal/api/middleware/idempotency.go`)
  runs inside `BeginRequestTx`, after auth and `SetRLS`.
- The raw body is read exactly once, hashed (`sha256(method + " " + path +
  NUL + body)`), and restored on `r.Body` so the handler decodes the exact
  bytes the client sent.
- A row is inserted into `idempotency_keys` (status `in_progress`) —
  **in the same request transaction as the guarded write**.
- The handler runs through a buffering recorder. On a successful response
  (`< 400`) the row is updated to `completed` with the status and body; the
  event/venue/application row and the idempotency record commit atomically.
- On a `>= 400` handler response the tx rolls back, so the record is not
  stored and a corrected retry starts fresh.
- **Expired** rows (`expires_at < now()`) are reaped opportunistically on each
  `Create`, so an `in_progress` row abandoned by a server failure self-heals
  after the TTL (24h) instead of trapping the key forever.

## Replay semantics (per spec §22)

Given an existing row for `(user_id, key)`:

| Existing status | Same request hash | Response |
|---|---|---|
| `completed` | yes | **Replay** the stored status/body verbatim; handler not re-run |
| `completed` | no | `409 idempotency_key_reused` |
| `in_progress` | any | `409 idempotency_in_progress` (client retries after the winner settles) |

Concurrency: `INSERT … ON CONFLICT (user_id, key) DO NOTHING` (not a plain
INSERT) is used deliberately — a competing unique-violation ERROR would abort
the surrounding Postgres transaction, making the follow-up lookup of the
existing row fail. `DO NOTHING` reports zero rows instead, so the transaction
stays usable. Competing writers still serialize on the unique index: a
competitor's uncommitted row blocks until it commits (we then replay) or rolls
back (we then insert). See `repository/idempotency.go`.

RLS: `idempotency_keys` rows are scoped to `user_id =
current_app_user_id()`; privileged `service`/`admin` contexts bypass RLS.
`UNIQUE (user_id, key)` bounds the key namespace per user (a client key
colliding across two users is two independent keys).

## Key lifetime

Keys live for **24 hours** (`idempotencyTTL`). After expiry the stored row is
reaped on the next `Create` for the same user, so the key is no longer honored
as a guard — semantically the idempotency window has closed and a client
reusing that key starts a **new** operation (including the theoretical
duplicate if the first attempt had actually succeeded but its response was
never seen). Clients that need a long-lived guarantee must generate a fresh key
per attempt after the window, which is the standard bounded-window contract
(e.g. Stripe's 24h idempotency keys). The TTL also frees keys trapped
in `in_progress` by a server crash.

## Safe without it — and why

- **Publish (`POST /events/{id}/publish`)** — status-guarded; a retry of an
  already-published event gets `409 event_not_draft`, so it cannot double-fire.
- **PATCH (`PATCH /events/{id}`)** — idempotent by nature: setting the same
  fields to the same values lands in the same state.
- **Registration (`POST /auth/register`)** — unique-email constraint rejects
  the duplicate; the client sees the existing error.
- **Email outbox writes** — `email_outbox.idempotency_key` has a unique index
  with `INSERT … ON CONFLICT DO NOTHING` (`docs/multi-step-operations.md §6`).
- **Refresh rotation** — consumed tokens are single-use by construction
  (`docs/multi-step-operations.md §4`).

Future mutating endpoints (RSVP, ticket orders, comments, likes, reviews,
reports — the spec's high-priority list) should be wrapped with this same
`Idempotency` middleware; it is per-route and opt-in.