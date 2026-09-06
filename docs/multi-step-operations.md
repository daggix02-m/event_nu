# Multi-Step Operations Audit

Status of every write that spans more than one table/row. For each operation
we record the **write order**, the **atomicity mechanism**, and whether
**partial completion is intentionally possible**.

Guiding invariant: an operation must either (a) be atomic — all steps land or
none — or (b) fail in a way that is *observably* partial and recoverable, never
silently inconsistent.

The atomicity spine is the per-request transaction
(`middleware.BeginRequestTx`), which wraps the entire route table in
`backend/internal/api/routes/routes.go`. It rolls back on any response `>= 400`
and commits on success. Repositories join that transaction via
`database.QuerierFromContext`. Where an operation needs a stronger guarantee
(concurrent single-winner), a guarded single `UPDATE … WHERE …` statement is
used in addition to the transaction.

---

## 1. Register — user + session (+ fire-and-forget emails)

- **Path:** `service/auth.go Register`; handler `handlers/auth.go Register`.
- **Write order:** `users` INSERT → `auth_sessions` INSERT → (after the 200)
  `email_outbox` INSERT (welcome) → `email_codes` INSERT + `email_outbox`
  INSERT (verification).
- **Atomicity mechanism:** request tx. User + session land or roll back
  together; a session-create failure surfaces as a 500 and removes the user
  row as well.
- **Partial completion possible?** Yes, for the email half, **intentionally**.
  The outbox writes happen after `.writeAuthResponse` and only log a warning on
  failure (they are fire-and-forget). The account is the source of truth; email
  delivery is best-effort and retried by the worker. A verification code may be
  stored without its outbox row — the user can request a fresh code later, so
  no state is trapped.

## 2. SendVerification — code + outbox

- **Path:** `service/email.go SendVerification`.
- **Write order:** `email_codes` INSERT (by hash) → `email_outbox` INSERT.
- **Atomicity mechanism:** request tx. Any failure between the two leaves the
  same tx to roll back the earlier insert, so you never get a code without a
  pending email or an email without a code.
- **Partial completion possible?** No, when called on its own. (The only
  exceptional path is the fire-and-forget call from Register above, where the
  enclosing tx has already committed the account on the 200.)

## 3. VerifyCode — consume + mark verified

- **Path:** `service/email.go VerifyCode`; `repository/emailcode.go Consume` +
  `repository/user.go UpdateVerified`.
- **Write order:** `email_codes` UPDATE (attempts+1, consumed_at) →
  `users` UPDATE (is_verified).
- **Atomicity mechanism:** `Consume` joins the request tx (it uses
  `database.Tx`, which adopts the surrounding request tx), so the consume and
  the verify land together. A user-verify failure rolls the code consumption
  back and the code stays usable.
- **Partial completion possible?** No. Either the code is consumed and the user
  is verified, or neither.

## 4. Refresh — atomic rotation

- **Path:** `service/auth.go Refresh`; `repository/session.go
  ConsumeForRotation`.
- **Write order:** `auth_sessions` UPDATE (revoked_at only, via the single
  `ConsumeForRotation` statement) → `users` read → `auth_sessions` INSERT
  (brand-new row).
- **Atomicity mechanism:** (1) `ConsumeForRotation` is a single `UPDATE …
  RETURNING … WHERE refresh_hash=$1 AND revoked_at IS NULL AND expires_at>now()`
  — the consume-and-revoke is one atomic statement, so N concurrent
  replays yield exactly one winner. (2) The whole rotation rides the request
  tx; if the later user lookup/insert fails and the handler returns an error,
  the revocation rolls back and the original token stays usable.
- **Partial completion possible?** No. Proven by `TestRefreshConcurrentSingleWinner`
  (8 goroutines → one 200, seven 401) and `TestConsumeForRotationConcurrent`.

## 5. Approve — review + organizer creation

- **Path:** `service/organizer.go Approve`; `repository/organizer.go
  ApproveApplication` + `CreateOrganizer`.
- **Write order:** `organizer_applications` UPDATE (status approved,
  reviewed_by, reviewed_at, notes) → `organizers` INSERT.
- **Atomicity mechanism:** (1) `ApproveApplication` is a single `UPDATE …
  RETURNING … WHERE id=$1 AND status='pending'` — the reviewer-wins-once guard.
  Two concurrent approvals each run the guarded UPDATE; Postgres re-evaluates
  the predicate after the first commits, so exactly one wins and the loser
  returns 409 (no read-then-update race). (2) The organizer INSERT shares the
  request tx; a create failure (e.g. slug unique violation) surfaces as a 500,
  the tx rolls back, and the application returns to `pending` — recoverable by
  editing the slug and re-applying.
- **Partial completion possible?** No. Proven by `TestApproveConcurrentSingleWinner`
  (two goroutines → one 200 + one 409, single organizer row) and
  `TestApproveRollbackOnOrganizerCreateFailure` (500 → application still pending).

## 6. Worker MarkSent / MarkFailed — outbox + email_logs

- **Path:** `worker/email.go sendOne`; `repository/outbox.go MarkSent` /
  `MarkFailed`.
- **Write order:** (claim: `email_outbox` UPDATE lease via
  `FOR UPDATE SKIP LOCKED`) → external provider send → `email_outbox` UPDATE
  (status/attempts/message id) + `email_logs` INSERT.
- **Atomicity mechanism:** `MarkSent` and `MarkFailed` each open their **own**
  transaction, UPDATE the outbox row and INSERT the log row, then commit —
  the outbox state and its log entry always match. `ClaimBatch` uses
  `FOR UPDATE SKIP LOCKED`, so a crashed worker's lease expires and the row is
  re-claimed rather than lost.
- **Partial completion possible?** Yes, **intentionally** at the send boundary:
  the provider send happens outside any transaction. A crash after a real send
  but before `MarkSent` means the row is re-claimed and re-sent — that is
  **at-least-once** delivery, which is the correct trade-off for transactional
  email (duplicates are rare and welcome/verify are idempotent from the user's
  perspective). Within a single Mark*, state is atomic.

---

## Cross-cutting notes

- **Idempotency for emails:** `email_outbox.idempotency_key` has a unique
  index and `INSERT … ON CONFLICT DO NOTHING` — the outbox is the replay guard
  for any future order receipts.
- **New operations:** follow the same template — enumerate write order, name
  the atomicity mechanism (request tx + guarded UPDATE when a concurrent
  single-winner is required), and state deliberately whether partial
  completion is OK. If partial is OK, the partial state must be observable and
  recoverable.