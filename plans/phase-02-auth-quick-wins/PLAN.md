# Phase 02 — Auth Quick Wins: Login Timing, Verify URL Removal, Log Redaction (WS3 + WS4)

## Goal

- Equalize login response time between "email not found" and "wrong password".
- Remove verification codes from URLs (kill `GET /api/v1/auth/verify?code=…`)
  and from all log lines.

## Impacted files

- `backend/internal/service/auth.go` (dummy bcrypt compare + spy hook)
- `backend/internal/service/auth_test.go` (timing-equivalence test)
- `backend/internal/service/email.go` (`verify_url` without code, `verify_code` param)
- `backend/internal/api/handlers/email.go` (delete `VerifyGET`)
- `backend/internal/api/routes/routes.go` (delete GET verify route)
- `backend/internal/api/middleware/middleware.go` (`LogRequest` logs path, not query)
- `backend/internal/api/middleware/middleware_test.go` (log-redaction test)
- `backend/internal/api/handlers/email_integration_test.go` (outbox/payload assertions)

## Tasks

- [ ] 1. `service/auth.go`: add package-level `var bcryptCompare = bcrypt.CompareHashAndPassword`
      and a fixed pre-generated dummy hash (cost 12, generated once at init).
- [ ] 2. Login: on user-not-found, run the dummy bcrypt compare (discard result)
      **before** returning `invalid_credentials`. Identical code/message/status on
      both paths. Never skip the dummy burn in the not-found path.
- [ ] 3. `service/email.go` `SendVerification`: emit `verify_url = "eventnu://verify"`
      (constant, no code) and a separate `verify_code` template param containing
      the 6-digit code; keep hashing + outbox enqueue unchanged.
- [ ] 4. Delete `VerifyGET` in `handlers/email.go` and the
      `GET /api/v1/auth/verify` registration in `routes.go`.
- [ ] 5. `middleware.go LogRequest`: replace `r.URL.RequestURI()` with
      `r.URL.Path` (never log query strings); keep method/status/duration/ip/request_id.
- [ ] 6. Tests:
      - Timing equivalence: inject a counting spy into `bcryptCompare`; assert
        not-found and wrong-password login each invoke bcrypt exactly once and
        return the same error code/status. (Proof-by-count, not flaky wall-clock.)
      - `GET /api/v1/auth/verify` → 405 (route gone).
      - Log redaction: log a request carrying `?code=SECRET&access_token=X` and
        assert the captured log output contains neither.
- [ ] 7. Run the gate; update `docs/PROGRESS.md`; commit on `main`.

## Verification gate

`gofmt -l` clean · build/vet PASS · `go test -race -p 1 ./...` PASS
(integration bits honest: DB present vs skipped).

## Definition of Done

- [ ] Login timing no longer reveals account existence.
- [ ] No verification code appears in any URL the API emits or accepts.
- [ ] `LogRequest` cannot dump query-string secrets; redaction test present.
- [ ] External contract unchanged for login errors; verify is POST-only.