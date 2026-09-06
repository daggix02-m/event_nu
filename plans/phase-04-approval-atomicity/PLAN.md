# Phase 04 — Atomic Organizer Approval + Multi-Step Audit (WS5 + WS6)

## Goal

Make approval/rejection atomic under concurrency (exactly one reviewer wins, no
half-approved state) and audit every other multi-write business operation for
atomicity or intentional partial behavior.

## Impacted files

- `backend/internal/repository/organizer.go` (`ApproveApplication`/`RejectApplication`)
- `backend/internal/service/organizer.go` (`Approve`/`Reject`)
- `backend/internal/api/handlers/organizers_test.go` (or a new approval test file)
- `docs/multi-step-operations.md` (new audit doc)

## Tasks

- [ ] 1. `repository/organizer.go`: add
      `ApproveApplication(ctx, id, adminUserID, notes) (*OrganizerApplication, error)`
      and `RejectApplication(...)` — guarded:
      ```sql
      UPDATE organizer_applications
      SET status = $2, reviewed_by = $3, reviewed_at = now(), review_notes = $4, updated_at = now()
      WHERE id = $1 AND status = 'pending'
      RETURNING <applicationColumns>
      ```
      Zero rows → `shared.ErrConflict`-typed `application_not_pending` (409).
- [ ] 2. `service/organizer.go`: `Approve`/`Reject` call the guarded methods
      (drop the non-atomic read-then-update). Approval + `CreateOrganizer` stay in
      the per-request tx → organizer-create failure rolls the app back to `pending`.
- [ ] 3. Integration tests:
      - success → app `approved`, one organizer row, reviewed_by/notes set;
      - duplicate approval → 409, exactly one organizer row;
      - organizer-create failure (pre-existing slug) → 500 and app **still pending**
        (rollback proven);
      - concurrent approvals (2 goroutines) → one 200 + one 409, single organizer row.
- [ ] 4. WS6 — write `docs/multi-step-operations.md` auditing every multi-write op:
      Register (user+session), SendVerification (code+outbox), VerifyCode
      (consume+verify), Refresh (rotation), Approve (review+organizer), worker
      MarkSent/MarkFailed (outbox+logs). For each: write order, atomicity
      mechanism, and whether partial completion is intentionally possible.
- [ ] 5. Run the gate; update `docs/PROGRESS.md`; commit on `main`.

## Verification gate

build/vet PASS · `go test -race -p 1 ./...` PASS (DB-backed approval matrix;
report DB availability honestly).

## Definition of Done

- [ ] Approval decision is atomic (`WHERE status='pending'` guard); concurrent
      approval yields one winner.
- [ ] Organizer-create failure rolls back the approval.
- [ ] Multi-write ops documented (atomic or intentional) in `docs/`.