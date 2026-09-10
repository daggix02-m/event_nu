# Ticket QR Protocol (Phase 14)

Status: implemented. Signed payloads are returned by `GET /api/v1/me/tickets`;
the check-in endpoint verifies them. (Offline signing on attendees' phones and an
anti-rollback registry are future work.)

## Trust boundary

A ticket is a right of admission. It is cheap to mint, so possession alone
cannot prove authenticity; the ticket *must* prove it was issued by the event's
backend. We achieve that with a symmetric signature (HMAC-SHA256) over the
ticket identity, keyed by the server-only secret `TICKET_QR_SECRET`.

The check-in device (organizer) submits the scanned payload to
`POST /api/v1/events/{id}/check-in`. The server:

1. Verifies the HMAC (constant-time) and that the payload's event matches the
   route — a forged or re-issued ticket is rejected as `invalid_code` (422).
2. Recomputes the stored `code_hash` and atomically marks the ticket used via
   the SECURITY DEFINER function `check_in_ticket(code_hash, event_id)`, which
   also proves the caller is this event's organizer.

## Cryptographic construction

- Canonical string (the only signed subject):

  ```
  canonical = ticket_id || "|" || event_id || "|" || issued_at(RFC3339, UTC)
  ```

- Stored code hash (unique, no secret — safe for DB uniqueness lookups):

  ```
  code_hash = hex(sha256(canonical))
  ```

- QR payload (what the client renders and the scanner submits):

  ```
  payload = { ticket_id,  event_id,  issued_at,  hmac }
  hmac    = hex(hmac_sha256(TICKET_QR_SECRET, canonical))
  ```

Notes:

- The HMAC covers exactly what is signed; the HMAC itself is *not* part of the
  canonical string (avoids circularity), and the payload's `ticket_id`/`event_id`
  are the same values that form the canonical — forgeries we care about mutate
  those and so break the HMAC.
- `code_hash` uses sha256 (no key) so lookups need no secret and are safe
  against enumeration (the input already contains a 128-bit random id).
- Issued-at is normalized to UTC RFC3339 with second precision before signing,
  so a scanner's formatting never affects the recomputed hash.

## Fields (server only)

| Field | Purpose | Access |
|---|---|---|
| `TICKET_QR_SECRET` | HMAC key (falls back to `JWT_SECRET`) | config, never serialized |
| `tickets.code_hash` | UNIQUE identity used by check-in | DB, privileged write |

## Lifecycle

1. `ConfirmPaid` (called by the Phase 15 payment webhook) issues tickets:
   canonical → `code_hash` stored; secret-kept HMAC returned in QR payload.
2. Attendee retrieves it from `GET /api/v1/me/tickets` and renders the QR.
3. Organizer scans; server verifies signature + event binding, then
   `check_in_ticket` flips `issued → used` and responds (rechecking returns
   `already_used` → 409).

## Security notes / future work

- **Replay window**: a used ticket is permanently rejected; a *copy* of a
  not-yet-used ticket scans successfully twice concurrently (already_used on
  the loser) — acceptable for admission.
- **Secret rotation** invalidates outstanding tickets; rotate in a low-activity
  window or re-issue wallets.
- **Attendee PII**: check-in responses return `user_id` only — `users` RLS hides
  attendees' profile rows from organizers (documented deliberate choice; a
  Phase-A after Phase 15 can expose name/email via a privileged endpoint if the
  venue UI needs it).
- **Offline signing** (attendee pre-signed time-slots) and an **anti-replay
  registry** (encrypted ticket id → timestamp) remain open follow-ups.