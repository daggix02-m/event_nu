# Phase 11 — Final Audit, Docs, and Report (WS-infra + WS-close)

## Goal

Close-out: full security/integrity re-audit of the changed surface, docs
finalization, full verification gate, and a written final report.

## Impacted files

- `backend/README.md` (final config table + auth/limiting/verification contract)
- `docs/PROGRESS.md` (final status: all phases)
- `docs/multi-step-operations.md`, `docs/idempotency.md` (cross-checked consistent)
- new `docs/SECURITY_HARDENING_FINAL_REPORT.md` (or equivalent final-report file)
- the whole `backend/` surface (audit read-only unless a finding requires a fix)

## Tasks

- [ ] 1. Security re-audit against the original ~17 findings (WS3/WS4/WS14/WS15/WS16
      and every phase checklist). Re-run the full checklist against the final tree;
      any lingering finding must be set to Fixed / Documented / Low & accepted —
      each with evidence. Track in `docs/SECURITY_HARDENING_FINAL_REPORT.md`.
- [ ] 2. Config cross-check: every env var read in `config/config.go` exists in
      `.env.example` + README table; no unknown/legacy vars documented as live.
- [ ] 3. Contract check: external API contract changes since baseline
      (verify GET→POST-only, pagination envelope, 429 shape, 409 bodies,
      idempotency) documented; error codes + status codes audited for consistency
      (no `22P02` 500, no secret-bearing URLs or logs).
- [ ] 4. Full verification gate from `backend/` with each command reported
      (PASS/FAIL/BLOCKED + real output): `gofmt -l .`, `go build ./...`,
      `go vet ./...`, `go test -race -p 1 -count=1 ./...`, `golangci-lint run`
      (BLOCKED if not installed), plus any docs-content lint if configured.
- [ ] 5. Write the **final report** file: findings-by-finding outcome table,
      tests added per phase, gate output, residual risks (each with an owner:
      multi-instance limiter needs Redis; golangci-lint needs installation; SMS
      path (WS15) treated as Low requires the same outbox+guard pattern), and a
      deployment checklist (migrations, env vars, single worker instance,
      multi-instance note).
- [ ] 6. Final commit on `main`, then present the report summary to the user.

## Verification gate

Full gate every command honestly reported · every finding has an evidence row ·
residual risks each have an owner/next-step.

## Definition of Done

- [ ] Every original finding resolved or explicitly documented with evidence.
- [ ] Docs consistent (README/progress/multi-step/idempotency/report).
- [ ] Final report written at `docs/SECURITY_HARDENING_FINAL_REPORT.md`.
- [ ] All work committed on `main`; summary presented.