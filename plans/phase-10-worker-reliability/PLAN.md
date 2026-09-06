# Phase 10 — Email Worker Reliability (WS17)

## Goal

Prove the outbox worker is safe under concurrency, lease expiry, and shutdown:
every email sent => `sent` row committed, no loss/duplicate on restart, graceful
drain with no in-flight email half-written.

## Impacted files

- `backend/internal/worker/email.go` (only if a defect is found — see DoD)
- `backend/internal/worker/email_test.go` (new: failure-injection + concurrency tests)
- `backend/internal/repository/outbox.go` (`ClaimPending`-adjacent test hook if needed)
- `docs/PROGRESS.md` / `docs/multi-step-operations.md` cross-ref

## Tasks

- [x] 1. Failure-injection test: make `SendBrevo` fail **after** the provider call
      but before `MarkSent` commits → assert the outbox row remains `pending`
      (retryable) and never a combination of `sent` + uncommitted.
- [x] 2. Concurrency test: N worker goroutines claiming the same pending rows →
      total sent == total claimed, no double-send (each row claimed once via the
      `SKIP LOCKED` lease).
- [x] 3. Lease-expiry test: a `claiming` row older than the lease interval becomes
      claimable again → recovery path works; bound the test with a short fake
      lease/clock.
- [x] 4. Graceful-shutdown test: worker drains in-flight claims before exit; a
      claim interrupted mid-send rolls back to `pending` (no loss).
- [x] 5. Only if a test surfaces a real defect: fix `worker/email.go` minimally
      (no new deps) and update `docs/multi-step-operations.md`'s worker row.
- [x] 6. Run the gate; update `docs/PROGRESS.md`; commit on `main`
      (commit may be test-only if no defect was found).

## Verification gate

build/vet PASS · `go test -race -p 1 ./...` PASS (DB-backed worker suite; report
DB availability honestly).

## Definition of Done

- [x] Worker suite proves at-least-once + no-duplicate under the three failure modes.
- [x] If a defect was found, it is fixed minimally and documented; otherwise the
      suite documents the existing guarantees.