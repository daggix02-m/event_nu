# Backend Security & Production Hardening — Phase Plans

This directory contains the task breakdown for the Event Nu Go backend hardening
work. Each `phase-NN-<name>/PLAN.md` is one session-sized unit of work. Work the
phases **in numeric order, one folder per session**; each phase is self-contained
(its own tasks, verification gate, and definition of done) and independently
verifiable.

## Phase index

| # | Folder | Workstream(s) | Requires |
|---|--------|---------------|----------|
| 00 | `phase-00-setup` | Bootstrap: plan folders, Go version consistency, baseline gate | none |
| 01 | `phase-01-ci-gates` | CI quality gates (fmt/vet/build/test behind a Postgres service) | 00 |
| 02 | `phase-02-auth-quick-wins` | Login timing side-channel, verify URL/GET removal, log redaction | 00 |
| 03 | `phase-03-refresh-atomicity` | Atomic refresh-token rotation (race fix) | 00 |
| 04 | `phase-04-approval-atomicity` | Atomic organizer approval + multi-step operations audit | 00 |
| 05 | `phase-05-rate-limiting` | In-memory auth rate limiting (login/register/refresh/verify) | 00 |
| 06 | `phase-06-admin-role-recheck` | Server-side admin role re-verification (stale JWT roles) | 00 |
| 07 | `phase-07-pagination` | Pagination + limits for public list endpoints | 00 |
| 08 | `phase-08-idempotency` | `idempotency_keys` table + replay middleware | 01 (CI Postgres, optional) |
| 09 | `phase-09-hardening` | Input validation (invalid UUIDs), lean `/metrics` | 00 |
| 10 | `phase-10-worker-reliability` | Email worker reliability tests | 00 |
| 11 | `phase-11-final-audit` | Full security audit, docs, final gate, report | all prior |

**Status: all 12 phases shipped on `main` (2026-09-06)** — see
`docs/SECURITY_HARDENING_FINAL_REPORT.md` for the findings-by-finding outcome
table and `docs/PROGRESS.md` Testing Log for per-phase evidence.

Sessions may pause/resume at any phase boundary. Do **02 before 09** (both touch
`LogRequest`). Do **01 before 08** if you want the idempotency migration exercised
in CI.

## Standard verification gate

Run at the end of **every** phase, from `backend/`:

```sh
gofmt -l .
go build ./...
go vet ./...
go test -race -p 1 -count=1 ./...   # -p 1 required: packages share one dev DB
golangci-lint run                     # BLOCKED if not installed — report it, don't skip silently
```

Report each command honestly as **PASS / FAIL / BLOCKED / NOT RUN** with the actual
output. Integration tests require Postgres (`DATABASE_URL`; dev uses Neon); they
`t.Skip` when unreachable — say so in the report rather than claiming a pass.

## Definition-of-done convention

A phase is done only when:

- every checklist item in its `PLAN.md` is ticked,
- the verification gate above is green (or each command is honestly reported),
- the diff is a focused set of commits on `main`,
- `docs/PROGRESS.md` is updated with the phase outcome.

## Source-of-truth documents

- Security/observability doctrine: skill references under
  `~/.config/opencode/skills/go/references/`
- Product spec: `docs/EVENT_NU_IMPLEMENTATION_DOCUMENTATION_v3.md` (pagination §4,
  rate limits §8.28, idempotency §8.29/§22)
- Running log: `docs/PROGRESS.md`