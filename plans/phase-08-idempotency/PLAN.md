# Phase 08 — Idempotency for Client-Retryable Writes (WS9)

## Goal

Make `POST /organizer-applications`, `POST /venues`, and `POST /events` safe
against mobile retries: a client-supplied `Idempotency-Key` prevents duplicate
creation, per spec §8.29/§22 (replay stored response for same key+request;
`409 idempotency_key_reused` for same key+different request).

## Impacted files

- `backend/migrations/00010_idempotency_keys.sql` (new)
- `backend/internal/repository/idempotency.go` (new)
- `backend/internal/api/middleware/idempotency.go` (new) + test
- `backend/internal/api/routes/routes.go` (wire middleware)
- `backend/internal/api/middleware/tx.go`-adjacent helpers (buffering recorder reuse)
- `docs/idempotency.md` (new decision log)
- new integration tests (events endpoint)

## Tasks

- [x] 1. Migration `00010_idempotency_keys.sql`:
      columns per spec — prehash-friendly deterministic key, `user_id uuid` FK,
      `key text`, `request_hash text`, `operation text`, `status`, `response_code int`,
      `response_body jsonb`, `created_at`, `expires_at`;
      `UNIQUE (user_id, key)`; index on `user_id` and `expires_at`;
      RLS policies (user own insert/select/update; privileged service/admin);
      `GRANT` to `app_user`.
- [x] 2. `repository/idempotency.go`: `Create(ctx, userID, key, requestHash,
      operation, ttl)`, `Get(ctx, userID, key)`, `Complete(ctx, userID, key,
      status, code, body)`, and an opportunistic
      `DELETE WHERE expires_at < now()` on create. Map the `23505` unique
      violation to a typed "already exists" outcome.
- [x] 3. New middleware `Idempotency(app)`:
      - no `Idempotency-Key` header → run through unchanged (opt-in);
      - hash = sha256(method + path + raw body); body is read once and restored
        for the handler;
      - record row in `in_progress` → run handler writing through a buffering
        response recorder → store status+body as `completed` (same request tx,
        so a 500 rolls the row back too);
      - existing row + same hash → **replay** stored status/body;
      - existing row + different hash → `409 idempotency_key_reused`;
      - racing concurrent same-key requests (unique-violation) → `409
        idempotency_in_progress` (client retries after settling).
- [x] 4. Wire onto the three protected POSTs (auth required; runs inside
      `BeginRequestTx`). Do **not** apply to Publish (already status-guarded) or
      PATCH (idempotent by nature).
- [x] 5. `docs/idempotency.md`: protected endpoints + mechanism + replay semantics;
      the "safe without it" list with reasons (Publish status-guard, PATCH
      set-same-fields, register unique-email, outbox unique key).
- [x] 6. Tests (events, DB): first request with key → 201; retry same key+same
      body → no duplicate (row count == 1) and stored response replayed;
      same key + different body → `409` and the second event was NOT created;
      no-key request composes normally.
- [x] 7. Run the gate; update `docs/PROGRESS.md`; commit on `main`.

## Verification gate

migrations apply cleanly · build/vet PASS · `go test -race -p 1 ./...` PASS
(DB-backed idempotency matrix; report DB availability honestly).

## Definition of Done

- [x] Spec §22 semantics live on the three write endpoints (replay / reused-409).
- [x] Decision log (`docs/idempotency.md`) lists protected vs safe endpoints.
- [x] Retry cannot create a duplicate row for protected writes.