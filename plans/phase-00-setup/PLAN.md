# Phase 00 — Setup & Baseline

## Goal

Bootstrap the phase structure so every later phase is a single-folder session,
confirm toolchain/`go.mod` agreement (WS11), and establish a recorded baseline
before any changes are made.

## Impacted files

- `plans/**` (all phase PLAN.md files, created by this phase)
- `backend/README.md` (Go version + integration-test instructions)
- `docs/PROGRESS.md` (baseline record)

## Tasks

- [ ] 1. Create `plans/README.md` index (phase table, order, gate commands, DoD convention).
- [ ] 2. Create `plans/phase-NN-<name>/PLAN.md` for phases 00–11 with Goal → Impacted files → Ordered tasks → Gate → DoD.
- [ ] 3. WS11 — verify the local toolchain matches `backend/go.mod` (`go 1.26.6`); note any drift.
- [ ] 4. WS11 — add a "Go version" + "how to run integration tests (Postgres/Neon)" section to `backend/README.md`.
- [ ] 5. Run the baseline gate from `backend/` and record actual output here:
      - `gofmt -l .`
      - `go build ./...`
      - `go vet ./...`
      - `go test -race -p 1 -count=1 ./...`
      - `golangci-lint run` → expect **BLOCKED** (not installed)
- [ ] 6. Record the baseline outcomes (PASS/FAIL/BLOCKED per command) in `docs/PROGRESS.md`.
- [ ] 7. Commit the phase on `main` with a focused message (e.g. `plans: scaffold hardening phase breakdown; record baseline gate`).

## Verification gate

`gofmt -l` clean · `go build ./...` PASS · `go vet ./...` PASS ·
`go test -race -p 1 -count=1 ./...` PASS (or honestly BLOCKED for DB tests).

## Definition of Done

- [ ] `plans/` layout exists and every phase folder contains a self-contained PLAN.md.
- [ ] Go version documented and consistent between toolchain and `go.mod`.
- [ ] Baseline gate command outcomes recorded with real output.
- [ ] Phase committed on `main`.